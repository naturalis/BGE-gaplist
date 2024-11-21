package Bio::BGE::GapList::TaxonRecord {
    use Moo;

    has [qw(phylum class order family species source)] => (
        is => 'rw',
    );

    has 'specimens' => (
        is => 'rw',
        default => sub { { long => 0, short => 0, failed => 0 } }
    );

    has 'verification' => (is => 'rw');
    has 'is_excluded' => (is => 'rw', default => 0);
    has 'synonyms' => (
        is => 'rw',
        default => sub { [] }
    );

    sub normalize_order {
        my ($self) = @_;
        return unless $self->order;

        # Standard taxonomic normalizations
        $self->order('Hemiptera') if $self->order eq 'Heteroptera';
        $self->order('Phasmatodea') if $self->family && $self->family eq 'Heteronemiidae';
        $self->order('Archaeognatha') if $self->family && $self->family eq 'Meinertellidae';
    }

    sub normalize_class {
        my ($self) = @_;
        return unless $self->class;
        $self->class('Copepoda') if $self->class eq 'Hexanauplia';
    }

    # Merges data from another record
    sub merge {
        my ($self, $other) = @_;
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