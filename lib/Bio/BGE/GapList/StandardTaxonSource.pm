package Bio::BGE::GapList::StandardTaxonSource {
    use Moo;
    use Bio::BGE::GapList::TaxonRecord
    extends 'Bio::BGE::GapList::TaxonSource';

    sub process_line {
        my ($self, $line, $context) = @_;
        chomp $line;
        my @fields = split /$self->{separator}/, $line;
        return unless @fields >= 5;  # Minimum fields needed

        my $record = Bio::BGE::GapList::TaxonRecord->new(
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

1;