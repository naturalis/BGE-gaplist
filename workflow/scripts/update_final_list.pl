use v5.14;
use utf8;
use open qw(:std :utf8);
use Path::Tiny;
use Try::Tiny;
use Bio::BGE::GapList::Logging;
use Data::Dumper;
use Getopt::Long;

=head1 NAME

update_final_list.pl - Update combined species lists with latest BOLD data

=head1 SYNOPSIS

    ./update_final_list.pl \
        --bold-data <bold_data_file> \
        --input <combined_lists_file> \
        --output <updated_lists_file>

=head1 DESCRIPTION

Final script in the taxonomic data pipeline. Merges the latest BOLD specimen
data into the combined species lists.

Pipeline order:
1. update_BOLD_data.pl  - Fetches current BOLD data
2. combine_lists.pl     - Combines multiple data sources
3. get_gap_lists.pl     - Analyzes coverage gaps
4. update_final_list.pl - This script: merges latest BOLD data

=head1 INPUT/OUTPUT

=head2 Input Files

- <bold_data_file>
  Format: species;taxon_id;barcoded_specimens;specimens;public_bins

- <combined_lists_file>
  Format: species;phylum;class;order;family;source;...

=head2 Output File

- <updated_lists_file>
  Format: species;phylum;class;order;family;source;barcoded_specimens;specimens;public_bins;[additional_fields]

=cut

# Command line options with defaults
my $bold_data_file = '../Curated_Data/23_07_2024_updated_BOLD_data.csv';
my $combined_lists_file = '../Curated_Data/combined_species_lists.csv';
my $updated_lists_file = '../Curated_Data/updated_combined_lists.csv';

# Parse command line options
GetOptions(
    'bold-data=s' => \$bold_data_file,
    'input=s'     => \$combined_lists_file,
    'output=s'    => \$updated_lists_file,
) or die "Error in command line arguments\n";

my $logger = Bio::BGE::GapList::Logging->get_logger(__PACKAGE__);

# Data structures
my %bold_data;

sub load_bold_data {
    my $file = path($bold_data_file);
    my $count = 0;

    try {
        my $fh = $file->openr_utf8();
        while (my $line = <$fh>) {
            chomp $line;
            my @fields = split /;/, $line;

            # Validate field count
            unless (@fields >= 5) {
                $logger->warn("Invalid BOLD data line: $line");
                next;
            }

            # Store data with validation
            $bold_data{$fields[0]} = {
                specbar => defined $fields[2] ? int($fields[2]) : undef,
                spec    => defined $fields[3] ? int($fields[3]) : undef,
                BINs    => defined $fields[4] ? int($fields[4]) : undef,
            };

            $count++;
        }
    }
    catch {
        die "Failed to load BOLD data: $_";
    };

    $logger->info("Loaded BOLD data for $count species");
    return $count;
}

sub process_combined_lists {
    my $input_file = path($combined_lists_file);
    my $output_file = path($updated_lists_file);
    my $count = 0;

    # Remove existing output file
    $output_file->remove if $output_file->exists;

    try {
        my $in_fh = $input_file->openr_utf8();
        my $out_fh = $output_file->openw_utf8();

        while (my $line = <$in_fh>) {
            chomp $line;
            my @fields = split /;/, $line;

            # Validate minimum field count
            unless (@fields >= 6) {
                $logger->warn("Invalid combined list line: $line");
                next;
            }

            # Write base fields
            print $out_fh join(';',
                @fields[0..5],                    # Original fields 0-5
                $bold_data{$fields[0]}{specbar} // '', # Barcoded specimens
                $bold_data{$fields[0]}{spec}    // '', # Total specimens
                $bold_data{$fields[0]}{BINs}    // ''  # Public BINs
            );

            # Add any additional fields from original data
            if (@fields > 9) {
                print $out_fh ';' . join(';', @fields[9..$#fields]);
            }

            print $out_fh "\n";
            $count++;
        }
    }
    catch {
        die "Failed to process combined lists: $_";
    };

    $logger->info("Processed $count species");
    return $count;
}

sub validate_output {
    my $file = path($updated_lists_file);
    my $line_count = 0;

    try {
        my $fh = $file->openr_utf8();
        while (my $line = <$fh>) {
            chomp $line;
            my @fields = split /;/, $line;

            # Validate minimum field count
            unless (@fields >= 9) {
                die "Invalid output line $.: insufficient fields";
            }

            # Validate numeric fields where present
            for my $idx (6..8) {
                next unless $fields[$idx];
                unless ($fields[$idx] =~ /^\d+$/) {
                    die "Invalid numeric field at line $., field $idx: $fields[$idx]";
                }
            }

            $line_count++;
        }
    }
    catch {
        die "Output validation failed: $_";
    };

    $logger->info("Validated $line_count species in output");
    return 1;
}

sub main {
    $logger->info("Starting final list update");

    # Load BOLD data
    my $bold_count = load_bold_data();

    # Process and merge data
    my $processed = process_combined_lists();

    # Validate output
    validate_output();

    $logger->info(sprintf(
        "Update complete. BOLD species: %d, Processed species: %d",
        $bold_count,
        $processed
    ));
}

# Run the program
eval {
    main();
};
if ($@) {
    $logger->error("Fatal error: $@");
    die $@;
}

__END__

=head1 AUTHOR

Fabian Deister, Rutger Vos

=head1 LICENSE

Copyright (c) 2024, Naturalis Biodiversity Center
All rights reserved.

=head1 SEE ALSO

L<update_BOLD_data.pl>
L<combine_lists.pl>
L<get_gap_lists.pl>

=cut