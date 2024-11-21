package Bio::BGE::GapList::TaxonomicCombiner {
    use Moo;
    use Log::Log4perl;
    use Path::Tiny;
    use Try::Tiny;

    # Initialize Log::Log4perl
    Log::Log4perl->init(\ qq(
        log4perl.rootLogger              = DEBUG, LOGFILE, Screen
        log4perl.appender.LOGFILE        = Log::Log4perl::Appender::File
        log4perl.appender.LOGFILE.filename = '../logs/taxonomic_combiner.log'
        log4perl.appender.LOGFILE.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.LOGFILE.layout.ConversionPattern = %d %p %m %n
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
    ));

    my $logger = Log::Log4perl->get_logger();

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

1;