package Bio::BGE::GapList::Logging;

use strict;
use warnings;
use Log::Log4perl;
use File::Basename qw(dirname);
use File::Spec;

sub import {
    my ($class, $config_file) = @_;

    unless ($config_file) {
        # Get directory containing the module
        my $module_dir = dirname(__FILE__);

        # Build path to config
        $config_file = File::Spec->catfile(
            $module_dir,
            '..', '..', '..', '..',
            'config', 'log4perl.conf'
        );

        # Normalize path
        $config_file = File::Spec->rel2abs($config_file);
    }

    # Initialize Log4perl
    if (-e $config_file) {
        Log::Log4perl->init($config_file);
    } else {
        die "Configuration file $config_file not found at: $config_file";
    }
}

sub get_logger {
    my ($class, $name) = @_;
    return Log::Log4perl->get_logger($name);
}

1;