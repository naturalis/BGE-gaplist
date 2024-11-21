package Bio::BGE::GapList::TaxonSource {
    use Moo;
    use Types::Standard qw(Str HashRef);

    has 'name' => (is => 'ro', isa => Str, required => 1);
    has 'path' => (is => 'ro', isa => Str, required => 1);
    has 'file' => (is => 'ro', isa => Str, required => 1);
    has 'separator' => (is => 'ro', isa => Str, default => ';');
    has 'verification_code' => (is => 'ro', isa => Str, required => 1);

    sub process_line { die "Subclass must implement process_line" }
}