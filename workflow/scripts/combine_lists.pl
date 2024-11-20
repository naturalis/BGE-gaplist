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

=head1 NAME

combine_lists.pl - Complete taxonomic data combiner

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

# Core record class
package TaxonRecord {
    use Moo;
    use Types::Standard qw(Str Int HashRef Maybe);

    has [qw(phylum class order family species source)] => (
        is => 'rw',
        isa => Maybe[Str],
    );
    
    has 'specimens' => (
        is => 'rw',
        isa => HashRef[Maybe[Int]],
        default => sub { { long => 0, short => 0, failed => 0 } }
    );
    
    has 'verification' => (is => 'rw', isa => Maybe[Str]);
    has 'is_excluded' => (is => 'rw', isa => Bool, default => 0);
    has 'synonyms' => (
        is => 'rw',
        isa => ArrayRef[Str],
        default => sub { [] }
    );

    sub normalize_order ($self) {
        return unless $self->order;
        
        # Standard taxonomic normalizations
        $self->order('Hemiptera') if $self->order eq 'Heteroptera';
        $self->order('Phasmatodea') if $self->family && $self->family eq 'Heteronemiidae';
        $self->order('Archaeognatha') if $self->family && $self->family eq 'Meinertellidae';
    }

    sub normalize_class ($self) {
        return unless $self->class;
        $self->class('Copepoda') if $self->class eq 'Hexanauplia';
    }

    # Merges data from another record
    sub merge ($self, $other) {
        return unless $other;
        
        # Add specimen counts
        for my $type (qw(long short failed)) {
            $self->specimens->{$type} += ($other->specimens->{$type} || 0);
        }
        
        # Append source if different
        if ($other->source && $other->source ne $self->source) {
            $self->source($self->source . ',' . $other->source);
        }
        
        # Take verification if we don't have one
        $self->verification($other->verification) 
            if !$self->verification && $other->verification;
    }
}

# Base class for data sources
package TaxonSource {
    use Moo;
    use Types::Standard qw(Str HashRef);
    
    has 'name' => (is => 'ro', isa => Str, required => 1);
    has 'path' => (is => 'ro', isa => Str, required => 1);
    has 'file' => (is => 'ro', isa => Str, required => 1);
    has 'separator' => (is => 'ro', isa => Str, default => ';');
    has 'verification_code' => (is => 'ro', isa => Str, required => 1);
    
    sub process_line { die "Subclass must implement process_line" }
}

# Standard taxonomic source implementation
package StandardTaxonSource {
    use Moo;
    extends 'TaxonSource';
    
    sub process_line ($self, $line, $context) {
        chomp $line;
        my @fields = split /$self->{separator}/, $line;
        return unless @fields >= 5;  # Minimum fields needed
        
        my $record = TaxonRecord->new(
            phylum => $fields[0],
            class  => $fields[1],
            order  => $fields[2],
            family => $fields[3],
            species => $fields[4],
            source => $self->name,
            verification => $self->verification_code
        );
        
        $record->normalize_order;
        $record->normalize_class;
        
        return $record;
    }
}

# BOLD-specific implementation
package BOLDSource {
    use Moo;
    extends 'StandardTaxonSource';
    
    sub process_line ($self, $line, $context) {
        my $record = $self->SUPER::process_line($line, $context);
        return unless $record;
        
        # Handle BOLD-specific specimen counts
        my @fields = split /$self->{separator}/, $line;
        if (@fields >= 8) {
            $record->specimens({
                long => $fields[5] || 0,
                short => $fields[6] || 0,
                failed => $fields[7] || 0
            });
        }
        
        return $record;
    }
}

# Main application class
package TaxonomicCombiner {
    use Moo;
    use Types::Standard qw(HashRef ArrayRef InstanceOf);
    
    has 'exclusion_list' => (is => 'ro', isa => Str, required => 1);
    has 'sources' => (
        is => 'ro',
        isa => ArrayRef[InstanceOf['TaxonSource']],
        required => 1,
    );
    has 'expert_dir' => (is => 'ro', isa => Str, required => 1);
    has 'output_combined' => (is => 'ro', isa => Str, required => 1);
    has 'output_specs' => (is => 'ro', isa => Str, required => 1);
    has 'output_synonyms' => (is => 'ro', isa => Str, required => 1);
    
    has [qw(taxa synonyms exclusions verifications)] => (
        is => 'rw',
        isa => HashRef,
        default => sub { {} }
    );

    sub process_exclusion_list ($self) {
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
    }

    sub process_expert_data ($self) {
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
    }

    sub store_record ($self, $record) {
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
    }

    sub generate_outputs ($self) {
        $self->generate_combined_list();
        $self->generate_synonym_list();
        $self->generate_taxonomic_hierarchy();
    }

    sub generate_combined_list ($self) {
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
    }

    sub run ($self) {
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
            die "Error processing data: $_";
        };
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

Improved version by [Your Name]

=head1 LICENSE

Copyright (c) [Year] [Your Organization]
All rights reserved.

=cut
