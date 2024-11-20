#!/usr/bin/perl
use v5.14;    # enables strict and warnings
use utf8;     # source code is UTF-8
use open qw(:std :utf8);
use File::Path qw(make_path remove_tree);
use Path::Tiny;
use Try::Tiny;
use Readonly;
use Moo;
use Types::Standard qw(Str Int HashRef ArrayRef Bool Maybe InstanceOf);
use namespace::clean;
use experimental 'signatures';

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
    
    # Configuration
    Readonly my $INPUT_DIR  => '../Raw_Data';
    Readonly my $OUTPUT_DIR => '../Curated_Data';
    
    has 'sources' => (
        is => 'ro',
        isa => ArrayRef[InstanceOf['TaxonSource']],
        default => sub {
            [
                BOLDSource->new(
                    name => 'BOLD',
                    path => 'BOLD_specieslist_europe',
                    file => '21_11_2022_public_specieslist_BOLD.csv',
                    verification_code => 'BOLD'
                ),
                StandardTaxonSource->new(
                    name => 'FaunaEuropaea',
                    path => 'Fauna_Europaea',
                    file => 'specieslist_FE.csv',
                    verification_code => 'FE'
                ),
                StandardTaxonSource->new(
                    name => 'WORMS',
                    path => 'WORMS',
                    file => 'specieslist_WORMS.csv',
                    verification_code => 'WORMS'
                ),
                StandardTaxonSource->new(
                    name => 'Lepiforum',
                    path => 'Lepiforum',
                    file => 'specieslist_Lepiforum.csv',
                    verification_code => 'LF'
                ),
                StandardTaxonSource->new(
                    name => 'iNaturalist',
                    path => 'inaturalist_germany',
                    file => 'speclist_inaturalist.csv',
                    verification_code => 'iNat'
                ),
                StandardTaxonSource->new(
                    name => 'ReptileDB',
                    path => 'reptile-database',
                    file => 'speclist_RDB.csv',
                    verification_code => 'RDB'
                ),
                StandardTaxonSource->new(
                    name => 'CoPH',
                    path => 'Catalogue_of_Palearctic_Heteroptera',
                    file => 'specieslist_CoPH.csv',
                    verification_code => 'CoPH'
                ),
                StandardTaxonSource->new(
                    name => 'Syrphidae',
                    path => 'Syrphidae.com',
                    file => 'speclist_Syrphidae.csv',
                    verification_code => 'Syr'
                ),
                StandardTaxonSource->new(
                    name => 'SyDip',
                    path => 'Systema_Dipterorum',
                    file => 'speclist_SyDip.csv',
                    verification_code => 'SyDip'
                ),
                StandardTaxonSource->new(
                    name => 'HySI',
                    path => 'Hymenoptera_Information_System',
                    file => 'speclist_HySI.csv',
                    verification_code => 'HySI'
                ),
                StandardTaxonSource->new(
                    name => 'DTN',
                    path => 'DTN_insecta',
                    file => 'speclist_DTN.csv',
                    verification_code => 'DTN'
                )
            ]
        }
    );
    
    has [qw(taxa synonyms exclusions verifications)] => (
        is => 'rw',
        isa => HashRef,
        default => sub { {} }
    );

    sub process_exclusion_list ($self) {
        my $file = path($OUTPUT_DIR, 'basic_exclusion_list.csv');
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
        my $expert_dir = path($INPUT_DIR, 'Additional_data_from_experts');
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
        my $file = path($OUTPUT_DIR, 'combined_species_lists.csv');
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
                my $file = path($INPUT_DIR, $source->path, $source->file);
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

my $combiner = TaxonomicCombiner->new();
$combiner->run();

__END__

=head1 AUTHOR

Improved version by [Your Name]

=head1 LICENSE

Copyright (c) [Year] [Your Organization]
All rights reserved.

=cut
