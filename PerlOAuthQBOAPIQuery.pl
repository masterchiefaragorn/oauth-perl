#!/opt/bin/perl -Tw

use warnings;
use Data::UUID ();
use Digest::HMAC_SHA1 ();
use HTTP::Request ();
use JSON::Parse qw(valid_json); # this is only necessary if you are asking QBO for a JSON response (as opposed to XML)
use LWP::UserAgent ();
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape);

our $company_id          = 1111111111;                                         # paste in the value that Intuit gave you for your QuickBooks Online Company ID
our $consumer_key        = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';                   # paste in the value that Intuit gave you for your application's Consumer Key
our $consumer_secret     = 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';         # paste in the value that Intuit gave you for your application's Consumer Secret
our $access_token        = 'dddddddddddddddddddddddddddddddddddddddddddddddd', # paste in the value from 'access_token'        that was printed out in OAuth Leg #3
our $access_token_secret = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',         # paste in the value from 'access_token_secret' that was printed out in OAuth Leg #3

my %params = (
	query => 'select * from customer',
);

my($time,$nonce) = (time(),Data::UUID->new->create_str);
my $hmac = Digest::HMAC_SHA1->new($consumer_secret . '&' . $access_token_secret);
$hmac->add('GET&' . uri_escape('https://sandbox-quickbooks.api.intuit.com/v3/company/' . $company_id . '/query') . '&' . uri_escape('oauth_consumer_key=' . $consumer_key . '&oauth_nonce=' . $nonce . '&oauth_signature_method=HMAC-SHA1&oauth_timestamp=' . $time . '&oauth_token=' . $access_token . '&oauth_version=1.0' . '&' . join('&',map {$_ . '=' . uri_escape($params{$_})} sort keys %params)));

my $request = HTTP::Request->new('GET','https://sandbox-quickbooks.api.intuit.com/v3/company/' . $company_id . '/query?' . join('&',map {$_ . '=' . uri_escape($params{$_})} sort keys %params));
$request->header(Accept => 'application/json');
$request->header(Authorization =>
	'OAuth oauth_consumer_key="' . $consumer_key
	. '",oauth_nonce="' . $nonce
	. '",oauth_signature="' . uri_escape(encode_base64($hmac->digest))
	. '",oauth_signature_method="HMAC-SHA1'
	. '",oauth_timestamp="' . $time
	. '",oauth_token="' . $access_token
	. '",oauth_version="1.0'
	. '"');

my $response = LWP::UserAgent->new->request($request);
print "SUCCESS\n" if $response->is_success;
if (valid_json($response->decoded_content)) {
	print $response->decoded_content . "\n";
} else {
	print "QuickBooks Online responded with unparsable JSON data.\n";
	print $response->decoded_content . "\n";
}
