use Test::More;
use Path::Tiny;
use strict;
use warnings;

# Get all Perl scripts
my @scripts = glob "workflow/scripts/*.pl";

# Plan the number of tests
plan tests => scalar(@scripts);

# Test each script
for my $script (@scripts) {
    my $output = `perl -cw $script 2>&1`;
    my $exit_code = $? >> 8;
    ok($exit_code == 0, "$script syntax is valid")
        or diag("Script failed syntax check: $output");
}

done_testing();
