use v5.14;    # enables strict and warnings
use utf8;     # source code is UTF-8
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
use Log::Log4perl;

# Initialize Log::Log4perl
Log::Log4perl->init(\ qq(
    log4perl.rootLogger              = DEBUG, LOGFILE, Screen
    log4perl.appender.LOGFILE        = Log::Log4perl::Appender::File
    log4perl.appender.LOGFILE.filename = '../logs/combine_lists.log'
    log4perl.appender.LOGFILE.layout = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.LOGFILE.layout.ConversionPattern = %d %p %m %n
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
));

my $logger = Log::Log4perl->get_logger();

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

# Main application class
package TaxonomicCombiner {
    use Moo;

    has 'exclusion_list' => (is => 'ro', required => 1);
    has 'sources' => (is => 'ro', required => 1);
    has 'expert_dir' => (is => 'ro', required => 1);
    has 'output_combined' => (is => 'ro', required => 1);
    has 'output_specs' => (is => 'ro', required => 1);
    has 'output_synonyms' => (is => 'ro', required => 1);

    has [qw(taxa synonyms exclusions verifications)] => (
        is => 'rw',
        default => sub { {} }
    );

    sub process_exclusion_list {
        my ($self) = @_;
        my $file = path($self->exclusion_list);
        my $fh = $file->openr_utf8();

        while (my $line = <$fh>) {
            chomp $line;
            my ($name, $action, $valid_name) = split /\t/, $line;

            if ($action eq 'e') {
                $self->exclusions->{$name} = 1;
            }
            if ($valid_name && $valid_name ne $name) {
                $self->synonyms->{$name} = $valid_name;
            }
        }
        $logger->info("Processed exclusion list");
    }

    sub process_expert_data {
        my ($self) = @_;
        my $expert_dir = path($self->expert_dir);
        for my $file ($expert_dir->children(qr/\.csv$/)) {
            my ($expert) = $file->basename =~ /([^_]+)\.csv/;
            next unless $expert;

            my $fh = $file->openr_utf8();
            while (my $line = <$fh>) {
                chomp $line;
                my $record = StandardTaxonSource->new(
                    name => $expert,
                    path => '.',
                    file => '.',
                    verification_code => $expert
                )->process_line($line, {});

                next unless $record;
                $self->store_record($record);
            }
        }
        $logger->info("Processed expert data");
    }

    sub store_record {
        my ($self, $record) = @_;
        return if $self->exclusions->{$record->species};

        # Handle synonyms
        if (my $valid_name = $self->synonyms->{$record->species}) {
            $record->species($valid_name);
        }

        # Store or merge record
        if (exists $self->taxa->{$record->species}) {
            $self->taxa->{$record->species}->merge($record);
        } else {
            $self->taxa->{$record->species} = $record;
        }
        $logger->debug("Stored record for species: " . $record->species);
    }

    sub generate_outputs {
        my ($self) = @_;
        $self->generate_combined_list();
        $self->generate_synonym_list();
        $self->generate_taxonomic_hierarchy();
        $logger->info("Generated all outputs");
    }

    sub generate_combined_list {
        my ($self) = @_;
        my $file = path($self->output_combined);
        my $fh = $file->openw_utf8();

        for my $species (sort keys %{$self->taxa}) {
            my $record = $self->taxa->{$species};
            print $fh join(';',
                $species,
                $record->phylum // '',
                $record->class // '',
                $record->order // '',
                $record->family // '',
                $record->source // '',
                $record->specimens->{long} // '',
                $record->specimens->{short} // '',
                $record->specimens->{failed} // '',
                $record->verification // ''
            ) . "\n";
        }
        $logger->info("Generated combined list");
    }

    sub run {
        my ($self) = @_;
        try {
            $self->process_exclusion_list();

            for my $source (@{$self->sources}) {
                my $file = path($source->path, $source->file);
                next unless -f $file;

                my $fh = $file->openr_utf8();
                while (my $line = <$fh>) {
                    my $record = $source->process_line($line, {
                        synonyms => $self->synonyms,
                        exclusions => $self->exclusions
                    });
                    $self->store_record($record) if $record;
                }
            }

            $self->process_expert_data();
            $self->generate_outputs();
        }
        catch {
            $logger->fatal("Error processing data: $_");
            die "Error processing data: $_";
        };
        $logger->info("Run completed successfully");
    }
}

# Main program
package main;

my $combiner = TaxonomicCombiner->new(
    exclusion_list => $exclusion_list,
    sources => [
        BOLDSource->new(
            name => 'BOLD',
            path => 'BOLD_specieslist_europe',
            file => $bold_data,
            verification_code => 'BOLD'
        ),
        StandardTaxonSource->new(
            name => 'FaunaEuropaea',
            path => 'Fauna_Europaea',
            file => $fauna_europaea,
            verification_code => 'FE'
        ),
        StandardTaxonSource->new(
            name => 'WORMS',
            path => 'WORMS',
            file => $worms,
            verification_code => 'WORMS'
        ),
        StandardTaxonSource->new(
            name => 'Lepiforum',
            path => 'Lepiforum',
            file => $lepiforum,
            verification_code => 'LF'
        ),
        StandardTaxonSource->new(
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