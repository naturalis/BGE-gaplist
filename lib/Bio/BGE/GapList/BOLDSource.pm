package Bio::BGE::GapList::BOLDSource {
    use Moo;
    extends 'Bio::BGE::GapList::StandardTaxonSource';

    sub process_line {
        my ($self, $line, $context) = @_;
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

1;