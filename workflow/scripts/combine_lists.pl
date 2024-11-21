use v5.14;
use utf8;
use open qw(:std :utf8);
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use Path::Tiny;
use Try::Tiny;
use Readonly;
use Moo;
use Types::Standard qw(Str Int HashRef ArrayRef Bool Maybe InstanceOf);
use namespace::clean;
use experimental 'signatures';
use Bio::BGE::GapList::TaxonSource;
use Bio::BGE::GapList::BOLDSource;
use Bio::BGE::GapList::StandardTaxonSource;
use Bio::BGE::GapList::TaxonomicCombiner;
use Bio::BGE::GapList::Logging;

my $logger = Bio::BGE::GapList::Logging->get_logger(__PACKAGE__);

# Command line options with defaults
my $exclusion_list = '../Curated_Data/basic_exclusion_list.csv';
my $bold_data = '../Raw_Data/BOLD_specieslist_europe/21_11_2022_public_specieslist_BOLD.csv';
my $fauna_europaea = '../Raw_Data/Fauna_Europaea/specieslist_FE.csv';
my $lepiforum = '../Raw_Data/Lepiforum/specieslist_Lepiforum.csv';
my $worms = '../Raw_Data/WORMS/specieslist_WORMS.csv';
my $inaturalist = '../Raw_Data/inaturalist_germany/speclist_inaturalist.csv';
my $expert_dir = '../Raw_Data/Additional_data_from_experts';
my $output_combined = '../Curated_Data/combined_species_lists.csv';
my $output_specs = '../Curated_Data/all_specs_and_syn.csv';
my $output_synonyms = '../Curated_Data/corrected_synonyms.csv';

# Parse command line options
GetOptions(
    'exclusion-list=s'   => \$exclusion_list,
    'bold-data=s'        => \$bold_data,
    'fauna-europaea=s'   => \$fauna_europaea,
    'lepiforum=s'        => \$lepiforum,
    'worms=s'            => \$worms,
    'inaturalist=s'      => \$inaturalist,
    'expert-dir=s'       => \$expert_dir,
    'output-combined=s'  => \$output_combined,
    'output-specs=s'     => \$output_specs,
    'output-synonyms=s'  => \$output_synonyms,
) or die "Error in command line arguments\n";

$logger->info("Command line options parsed successfully");

=head1 NAME

combine_lists.pl - Complete taxonomic data combiner

=head1 SYNOPSIS

    combine_lists.pl \
        --exclusion-list=<exclusion list file> \
        --bold-data=<BOLD data file> \
        --fauna-europaea=<Fauna Europaea data file> \
        --lepiforum=<Lepiforum data file> \
        --worms=<WORMS data file> \
        --inaturalist=<iNaturalist data file> \
        --expert-dir=<directory containing expert data files> \
        --output-combined=<combined species list file> \
        --output-specs=<specifications file> \
        --output-synonyms=<output synonyms file>

=head1 DESCRIPTION

Processes taxonomic data from multiple sources:
- BOLD (Barcode of Life Data System)
- Fauna Europaea
- WORMS (World Register of Marine Species)
- Lepiforum
- iNaturalist
- Reptile Database
- Catalogue of Palearctic Heteroptera
- Syrphidae Database
- Systema Dipterorum
- Hymenoptera Information System
- DTN Insecta Database
- Expert data

Handles taxonomic hierarchies, synonyms, and specimen counts.

=cut

my $combiner = Bio::BGE::GapList::TaxonomicCombiner->new(
    exclusion_list => $exclusion_list,
    sources => [
        Bio::BGE::GapList::BOLDSource->new(
            name => 'BOLD',
            path => 'BOLD_specieslist_europe',
            file => $bold_data,
            verification_code => 'BOLD'
        ),
        Bio::BGE::GapList::StandardTaxonSource->new(
            name => 'FaunaEuropaea',
            path => 'Fauna_Europaea',
            file => $fauna_europaea,
            verification_code => 'FE'
        ),
        Bio::BGE::GapList::StandardTaxonSource->new(
            name => 'WORMS',
            path => 'WORMS',
            file => $worms,
            verification_code => 'WORMS'
        ),
        Bio::BGE::GapList::StandardTaxonSource->new(
            name => 'Lepiforum',
            path => 'Lepiforum',
            file => $lepiforum,
            verification_code => 'LF'
        ),
        Bio::BGE::GapList::StandardTaxonSource->new(
            name => 'iNaturalist',
            path => 'inaturalist_germany',
            file => $inaturalist,
            verification_code => 'iNat'
        ),
        # Add other sources as needed...
    ],
    expert_dir => $expert_dir,
    output_combined => $output_combined,
    output_specs => $output_specs,
    output_synonyms => $output_synonyms
);
$combiner->run();

__END__

=head1 AUTHOR

Fabian Deister, Rutger Vos

=head1 LICENSE

Copyright (c) 2024, Naturalis Biodiversity Center
All rights reserved.

=head1 SEE ALSO

L<update_BOLD_data.pl>
L<update_final_list.pl>
L<get_gap_lists.pl>

=cut