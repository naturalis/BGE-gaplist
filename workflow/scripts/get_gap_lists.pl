use v5.14;    # enables strict and warnings
use utf8;     # source code is UTF-8
use open qw(:std :utf8);    # all filehandles UTF-8 by default
use File::Path qw(remove_tree make_path);
use Path::Tiny;
use Try::Tiny;
use Readonly;
use DateTime;
use Getopt::Long;

=head1 NAME

get_gap_lists.pl - Generate taxonomic gap analysis lists

=head1 SYNOPSIS

    ./get_gap_lists.pl --input <input_file> --bold-ids <bold_ids_file> --output <output_file> --output-dir <output_dir>

=head1 DESCRIPTION

This script processes taxonomic data to identify and report gaps in species documentation.
It reads species data from CSV files and generates reports organized by taxonomic hierarchy
(Phylum/Class/Order/Family). The script identifies species lacking proper documentation
and generates both detailed family-level reports and a comprehensive gap analysis.

=head1 INPUT FILES

=over 4

=item * <input_file>

Main taxonomic data file with fields:
species;phylum;class;order;family;source;specimens_barcoded;specimens;public_bins;verified_by

=item * <bold_ids_file>

BOLD ID mappings with format:
species,bold_id

=back

=head1 OUTPUT

Creates hierarchical directory structure under <output_dir>/sorted/ containing:
- Family-level CSV files with gap analysis
- Comprehensive gap list in <output_file>

=head1 AUTHOR

Original author unknown
Improved version by [Your Name]

=cut

# Command line options with defaults
my $input_file = '../Curated_Data/updated_combined_lists.csv';
my $bold_ids_file = '../Curated_Data/all_syn_BOLD_IDs.csv';
my $output_file = '../Gap_Lists/Gap_list_all.csv';
my $output_dir = '../Gap_Lists/sorted';

# Parse command line options
GetOptions(
    'input=s'       => \$input_file,
    'bold-ids=s'    => \$bold_ids_file,
    'output=s'      => \$output_file,
    'output-dir=s'  => \$output_dir,
) or die "Error in command line arguments\n";

# Constants
Readonly my $INPUT_DIR       => path($input_file)->parent;
Readonly my $OUTPUT_DIR      => path($output_file)->parent;
Readonly my $SORTED_DIR      => $output_dir;
Readonly my $COMBINED_OUTPUT => $output_file;

# Main data structures
my %bold_ids;      # Species to BOLD ID mapping
my %metadata;      # Species metadata
my %taxonomy;      # Family to species mapping
my %classifications; # Family classification details
my @family_list;   # List of unique families

main();

sub main {
    setup_directories();
    load_bold_ids();
    process_taxonomic_data();
    generate_reports();
}

sub setup_directories {
    # Clean and recreate output directories
    try {
        remove_tree($SORTED_DIR) if -d $SORTED_DIR;
        make_path($SORTED_DIR);
    }
    catch {
        die "Failed to set up directories: $_";
    };
}

sub load_bold_ids {
    my $bold_file = path($bold_ids_file);
    
    try {
        my $fh = $bold_file->openr_utf8();
        while (my $line = <$fh>) {
            chomp $line;
            my ($species, $bold_id) = split /,/, $line, 2;
            $bold_ids{$species} = $bold_id if $species && $bold_id;
        }
    }
    catch {
        die "Failed to process BOLD IDs file: $_";
    };
}

sub process_taxonomic_data {
    my $data_file = path($input_file);
    
    try {
        my $fh = $data_file->openr_utf8();
        while (my $line = <$fh>) {
            chomp $line;
            process_taxonomic_line($line);
        }
    }
    catch {
        die "Failed to process taxonomic data: $_";
    };
}

sub process_taxonomic_line {
    my ($line) = @_;
    
    my ($species, $phylum, $class, $order, $family, @rest) = split /;/, $line;
    return unless $species && $family;  # Skip invalid lines
    
    # Clean up taxonomic names
    $family =~ s/\s/_/g;
    $order  =~ s/\s/_/g;
    
    # Store metadata
    $metadata{$species} = {
        line => $line,
        gap_status => determine_gap_status(@rest),
    };
    
    # Store taxonomic relationships
    push @{$taxonomy{$family}}, $species;
    
    # Store classification details
    $classifications{$family} //= {
        phylum => $phylum || 'no_phylum_assigned',
        class  => $class  || 'no_class_assigned',
        order  => $order  || 'no_order_assigned',
    };
    
    # Track unique families
    unless (grep { $_ eq $family } @family_list) {
        push @family_list, $family;
    }
}

sub determine_gap_status {
    my ($source, $long, $short, $fail) = @_;
    
    return 'gap' unless defined $long && $long =~ /\d/;
    return 'gap' if $long eq '0';
    return '';
}

sub generate_reports {
    my $date = DateTime->now->ymd;
    
    # Open main output file
    my $main_out = path($COMBINED_OUTPUT)->openw_utf8();
    
    foreach my $family (@family_list) {
        my $class = $classifications{$family};
        
        # Create family directory path
        my $family_dir = path(
            $SORTED_DIR,
            $class->{phylum},
            $class->{class},
            $class->{order}
        );
        make_path($family_dir);
        
        # Open family-specific output file
        my $family_file = $family_dir->child("${date}_${family}.csv");
        my $family_out = $family_file->openw_utf8();
        
        # Write headers
        print_headers($family_out);
        print $main_out "\n" if tell($main_out) > 0;  # Add newline except for first entry
        print $main_out "$family\n";
        
        # Write species data
        write_species_data($main_out, $family_out, $family);
    }
}

sub print_headers {
    my ($fh) = @_;
    print $fh join(';',
        'species',
        'Phylum',
        'Class',
        'Order',
        'Family',
        'source',
        'specimens barcoded',
        'specimens',
        'public BINs',
        'verified by',
        'status',
        'BOLD taxid'
    ) . "\n";
}

sub write_species_data {
    my ($main_out, $family_out, $family) = @_;
    
    foreach my $species (sort @{$taxonomy{$family}}) {
        my $metadata = $metadata{$species};
        my $output_line = $metadata->{line};
        
        if (my $bold_id = $bold_ids{$species}) {
            # Add BOLD IDs as semicolon-separated list
            my @unique_ids = do {
                my %seen;
                grep { !$seen{$_}++ } split /,/, $bold_id;
            };
            $output_line .= ';' . join(';', @unique_ids);
        }
        
        # Add gap status
        $output_line .= ';' . $metadata->{gap_status};
        
        # Write to both outputs
        print $main_out "$output_line\n";
        print $family_out "$output_line\n";
    }
}

=head1 LICENSE

Copyright (c) [Year] [Your Organization]
All rights reserved.

=cut

__END__
