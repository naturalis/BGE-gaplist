use Test::More;
use Path::Tiny;
use strict;
use warnings;

# Create test data directory
my $test_data = path('t/data');
$test_data->mkpath;

# Test file reading
my $test_file = $test_data->child('test.csv');
$test_file->spew("species;phylum;class;order;family\n");

# Test basic file operations
ok(-e $test_file, "Test file exists");
my $content = $test_file->slurp_utf8;
like($content, qr/species;phylum;class;order;family/, "File content is correct");

done_testing();
