use v5.14;
use utf8;
use open qw(:std :utf8);
use JSON::PP;
use HTTP::Tiny;
use Try::Tiny;
use Time::HiRes qw(sleep);
use Readonly;
use Log::Any qw($log);
use Log::Any::Adapter ('File', '../logs/bold_update.log');
use Getopt::Long;

=head1 NAME

update_BOLD_data.pl - BOLD Systems API Data Updater

=head1 SYNOPSIS

    ./update_BOLD_data.pl --input <input_file> --output <output_file> --log <log_file> [--retry-limit=N] [--rate-limit=N]

=head1 DESCRIPTION

This script is part of the taxonomic data processing pipeline. It queries the
BOLD Systems API to retrieve current specimen and barcode data for species.

Pipeline order:
1. update_BOLD_data.pl (this script)
2. combine_lists.pl
3. get_gap_lists.pl

=head2 Process Flow

1. Reads species names from all_specs_and_syn.csv
2. For each species:
   - Queries BOLD TaxonSearch API to get taxon ID
   - Queries BOLD TaxonData API to get specimen data
   - Records barcode specimens, total specimens, and public BINs
3. Outputs updated data to CSV for use by combine_lists.pl

=head2 Error Handling

- Implements retry logic for failed API requests
- Rate limiting to prevent API overload
- Logs all errors and warnings
- Skips problematic species but continues processing
- Validates all API responses

=head1 INPUT/OUTPUT

=head2 Input File

../Curated_Data/all_specs_and_syn.csv
Format: semicolon-separated species names and synonyms

=head2 Output File

../Raw_Data/BOLD_specieslist_europe/updated_BOLD_data.csv
Format: species;taxon_id;barcode_specimens;specimen_records;public_bins

=head1 CONFIGURATION

=cut

# Command line options with defaults
my $input_file  = '../Curated_Data/all_specs_and_syn.csv';
my $output_file = '../Raw_Data/BOLD_specieslist_europe/updated_BOLD_data.csv';
my $log_file    = '../logs/bold_update.log';
my $retry_limit = 3;
my $rate_limit  = 1;
my $timeout     = 30;
my $batch_size  = 100;

# Parse command line options
GetOptions(
    'input=s'       => \$input_file,
    'output=s'      => \$output_file,
    'log=s'         => \$log_file,
    'retry-limit=i' => \$retry_limit,
    'rate-limit=i'  => \$rate_limit,
    'timeout=i'     => \$timeout,
    'batch-size=i'  => \$batch_size,
) or die "Error in command line arguments\n";

# Constants for configuration
Readonly our $CONFIG => {
    INPUT_FILE  => $input_file,
    OUTPUT_FILE => $output_file,
    LOG_FILE    => $log_file,
    API_BASE    => 'http://v3.boldsystems.org/index.php/API_Tax',
    MAX_RETRIES => $retry_limit,
    RATE_LIMIT  => $rate_limit,
    TIMEOUT     => $timeout,
    BATCH_SIZE  => $batch_size,
};

# Derived constants
Readonly our $ENDPOINTS => {
    search => "$CONFIG->{API_BASE}/TaxonSearch",
    data   => "$CONFIG->{API_BASE}/TaxonData",
};

# Initialize HTTP client
my $http = HTTP::Tiny->new(
    timeout => $CONFIG->{TIMEOUT},
    agent   => 'TaxonomicPipeline/1.0',
    verify_SSL => 1,
);

# Track processed taxa to avoid duplicates
my %processed_taxa;

=head1 SUBROUTINES

=head2 make_api_request($url, $params)

Makes an HTTP GET request to the BOLD API with retry logic and error handling.

Parameters:
- $url: API endpoint URL
- $params: HashRef of query parameters

Returns: Decoded JSON response or undef on failure

=cut

sub make_api_request {
    my ($url, $params) = @_;
    
    # Input validation
    die "URL required" unless $url;
    die "Parameters must be hashref" unless ref $params eq 'HASH';
    
    for my $try (1..$CONFIG->{MAX_RETRIES}) {
        # Rate limiting
        sleep($CONFIG->{RATE_LIMIT}) if $try > 1;
        
        # Construct query string
        my $query_string = join('&', 
            map { "$_=" . url_escape($params->{$_}) } 
            keys %$params
        );
        
        # Make request
        my $response = try {
            $http->get("$url?$query_string");
        }
        catch {
            $log->error("Request failed: $_");
            return;
        };
        
        # Check for HTTP success
        if ($response->{success}) {
            # Parse JSON response
            my $data = try {
                decode_json($response->{content});
            }
            catch {
                $log->error("JSON parse error: $_");
                return;
            };
            
            # Validate response structure
            return validate_response($data);
        }
        
        # Log failed attempt
        $log->warn(sprintf(
            "Request failed (attempt %d/%d): %s %s", 
            $try,
            $CONFIG->{MAX_RETRIES},
            $response->{status},
            $response->{reason}
        ));
    }
    
    $log->error("Max retries exceeded for URL: $url");
    return;
}

=head2 validate_response($data)

Validates the structure of API responses.

Parameters:
- $data: Decoded JSON response

Returns: Validated data or undef if invalid

=cut

sub validate_response {
    my ($data) = @_;
    
    return unless $data;
    
    # Check for API error responses
    if (exists $data->{error}) {
        $log->error("API error: $data->{error}");
        return;
    }
    
    # Validate required fields based on endpoint
    if (exists $data->{taxid}) {
        # TaxonSearch response
        return unless $data->{taxid} =~ /^\d+$/;
    }
    elsif (exists $data->{barcodespecimens}) {
        # TaxonData response
        for my $field (qw(barcodespecimens specimenrecords publicbins)) {
            return unless exists $data->{$field};
            $data->{$field} = 0 unless $data->{$field} =~ /^\d+$/;
        }
    }
    else {
        $log->error("Unknown response format");
        return;
    }
    
    return $data;
}

=head2 get_taxon_id($species)

Queries the BOLD TaxonSearch API to get taxon ID for a species.

Parameters:
- $species: Species name string

Returns: Taxon ID or undef if not found

=cut

sub get_taxon_id {
    my ($species) = @_;
    
    return unless $species;
    
    my $data = make_api_request($ENDPOINTS->{search}, {
        taxName => $species
    });
    
    return $data ? $data->{taxid} : undef;
}

=head2 get_taxon_data($taxon_id)

Queries the BOLD TaxonData API to get specimen data for a taxon ID.

Parameters:
- $taxon_id: BOLD taxon ID

Returns: HashRef of specimen data or undef on failure

=cut

sub get_taxon_data {
    my ($taxon_id) = @_;
    
    return unless $taxon_id && $taxon_id =~ /^\d+$/;
    
    return make_api_request($ENDPOINTS->{data}, {
        taxId => $taxon_id,
        dataTypes => 'basic,stats'
    });
}

=head2 process_species($species)

Processes a single species through the BOLD API pipeline.

Parameters:
- $species: Species name string

Returns: 1 on success, 0 on failure

=cut

sub process_species {
    my ($species) = @_;
    
    # Skip if already processed
    return 1 if $processed_taxa{$species};
    
    # Clean species name
    $species = clean_species_name($species);
    return 0 unless $species;
    
    # Get taxon ID
    my $taxon_id = get_taxon_id($species);
    unless ($taxon_id) {
        $log->warn("No taxon ID found for species: $species");
        return 0;
    }
    
    # Skip if taxon already processed
    return 1 if $processed_taxa{$taxon_id};
    
    # Get specimen data
    my $data = get_taxon_data($taxon_id);
    unless ($data) {
        $log->warn("No specimen data found for taxon ID: $taxon_id");
        return 0;
    }
    
    # Create record
    my $record = {
        species => $species,
        taxon_id => $taxon_id,
        barcode_specimens => $data->{barcodespecimens} // 0,
        specimen_records => $data->{specimenrecords} // 0,
        public_bins => $data->{publicbins} // 0,
    };
    
    # Save record
    return 0 unless save_record($record);
    
    # Mark as processed
    $processed_taxa{$taxon_id} = 1;
    $processed_taxa{$species} = 1;
    
    return 1;
}

=head2 clean_species_name($species)

Cleans and validates a species name.

Parameters:
- $species: Raw species name string

Returns: Cleaned species name or undef if invalid

=cut

sub clean_species_name {
    my ($species) = @_;
    
    return unless $species =~ /\S/;
    
    # Remove leading/trailing whitespace
    $species =~ s/^\s+|\s+$//g;
    
    # Normalize internal whitespace
    $species =~ s/\s+/ /g;
    
    # Basic validation
    return unless $species =~ /^[A-Za-z][A-Za-z\s\.-]+$/;
    
    return $species;
}

=head2 save_record($record)

Saves a species record to the output file.

Parameters:
- $record: HashRef of species data

Returns: 1 on success, 0 on failure

=cut

sub save_record {
    my ($record) = @_;
    
    state $out_fh = do {
        open my $fh, '>:utf8', $CONFIG->{OUTPUT_FILE}
            or die "Cannot open output file: $!";
        $fh;
    };
    
    try {
        say $out_fh join(';',
            $record->{species},
            $record->{taxon_id},
            $record->{barcode_specimens},
            $record->{specimen_records},
            $record->{public_bins}
        );
        return 1;
    }
    catch {
        $log->error("Failed to save record: $_");
        return 0;
    };
}

=head2 url_escape($string)

Simple URL escaping function.

Parameters:
- $string: String to escape

Returns: URL-escaped string

=cut

sub url_escape {
    my ($string) = @_;
    $string =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/ge;
    return $string;
}

=head2 main()

Main program entry point.

=cut

sub main {
    $log->info("Starting BOLD data update");
    
    # Remove existing output file
    if (-e $CONFIG->{OUTPUT_FILE}) {
        unlink $CONFIG->{OUTPUT_FILE}
            or die "Cannot remove existing output file: $!";
    }
    
    # Open input file
    open my $in_fh, '<:utf8', $CONFIG->{INPUT_FILE}
        or die "Cannot open input file: $!";
    
    my $processed = 0;
    my $success = 0;
    
    # Process each line
    while (my $line = <$in_fh>) {
        chomp $line;
        my @species = split /;/, $line;
        
        for my $species (@species) {
            $processed++;
            $success++ if process_species($species);
            
            # Progress report
            if ($processed % $CONFIG->{BATCH_SIZE} == 0) {
                $log->info(sprintf(
                    "Processed %d species (%d successful)",
                    $processed,
                    $success
                ));
            }
        }
    }
    
    # Final statistics
    $log->info(sprintf(
        "Processing complete. Total: %d, Successful: %d, Failed: %d",
        $processed,
        $success,
        $processed - $success
    ));
}

# Run the program
eval {
    main();
};
if ($@) {
    $log->error("Fatal error: $@");
    die $@;
}

__END__

=head1 AUTHOR

[Your Name]

=head1 LICENSE

Copyright (c) [Year] [Your Organization]
All rights reserved.

=head1 SEE ALSO

L<combine_lists.pl>
L<get_gap_lists.pl>

=cut
