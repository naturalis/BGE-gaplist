use Test::More;
use strict;
use warnings;

# Mock BOLD API responses
use Test::Mock::LWP::Conditional;
use HTTP::Response;
use JSON::PP;

# Load the BOLD update script
require_ok('../workflow/scripts/update_BOLD_data.pl');

# Test API response parsing
my $mock_response = encode_json({
    taxid => "12345",
    barcodespecimens => "10",
    specimenrecords => "20",
    publicbins => "2"
});

# Mock the API request
$mock_ua->map('http://v3.boldsystems.org/index.php/API_Tax/TaxonData',
    HTTP::Response->new(200, 'OK', [], $mock_response));

# Test parsing
my $result = parse_bold_response($mock_response);
is($result->{taxid}, "12345", "Correctly parsed taxon ID");
is($result->{barcodespecimens}, "10", "Correctly parsed specimen count");

done_testing();
