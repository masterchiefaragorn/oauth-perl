#!/opt/bin/perl -Tw

# oauth-perl
# ==========
# A Perl script for establishing an OAuth connection to Intuit's QuickBooks Online and making a QBO API call
# by Eric Simon, a developer for Vertical Approach, LLC.
#
# Usage:
#   PerlOAuthQBOAPI.pl RequestToken|AccessToken|API
#
# PerlOAuthQBOAPI.pl takes a single argument, which is RequestToken, AccessToken, or API.  My goal in creating this
# script for the community was to pare it down to the simplist elements required to finally acquire an Access Token
# from Intuit for QuickBooks Online and to use that Access Token to make your first QBO API call.  I purposefully
# did not try to embed this into a webserver to more automate the authentication part of OAuth (Leg #2) since folks
# that will be using this script will be doing so in a variety of web server environments.  Also, I opted not to
# leverage the Net::OAuth on CPAN for no other reason than the fact that I like less packages on my machines.  :)

use warnings;
use Data::Dumper qw(Dumper); # this is only here so you can visually see the results of the API call that got stored in a Perl hash
use Data::UUID ();
use Digest::HMAC_SHA1 ();
use HTTP::Request ();
use JSON::Parse qw(valid_json json_to_perl); # this is only necessary if you are asking QBO for a JSON response (as opposed to XML)
use LWP::UserAgent ();
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape);

our $company_id      = 1111111111;                                 # paste in the value that Intuit gave you for your QuickBooks Online Company ID
our $consumer_key    = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';           # paste in the value that Intuit gave you for your application's Consumer Key
our $consumer_secret = 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'; # paste in the value that Intuit gave you for your application's Consumer Secret
our $callback        = 'https://some.url.com/somepath';            # paste the URL for your application that will execute the code OAuth Leg #3 (requesting the Access Token)

if ($ARGV[0] eq 'RequestToken') {
	# OAuth Leg #1 - Get the Request Token from Intuit.
	my $response = SendOAuthRequest('RequestToken',
		callback        => $callback,
		consumer_key    => $consumer_key,
		consumer_secret => $consumer_secret,
	);
	if ($response->is_success) {
		my %vals = map {split(/=/,$_)} split(/&/,$response->decoded_content);
		print 'https://appcenter.intuit.com/Connect/Begin?oauth_token=' . $vals{oauth_token} . "\n";
		print 'request_token_secret = ' . $vals{oauth_token_secret} . "\n"; # copy this value into OAuth Leg #3

		# OAuth Leg #2 - Manually authorize the connection to QBO.
		# To do this, copy the appcenter.intuit.com link (that was printed out above) into a browser, log in to Intuit, and
		# then click the "Authorize" button.  After doing this, your app should be successfully authorized, and Intuit will
		# redirect the browser to the callback URL you specified above.  Now copy the values from the oauth_token and the
		# oauth_verifier from the end of the URL (that is now sitting in your browser address window) and paste them into
		# the arguments to the call to SendOAuthRequest() in the code block below for "OAuth Leg #3".  Here is an example
		# of the URL that Intuit will redirect the browser to:
		#
		# https://some.url.com/somepath?oauth_token=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&oauth_verifier=ccccccc&realmId=1111111111&dataSource=QBO
		# ...so in this case, the value for oauth_token is aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
		# and the value for oauth_verifier is ccccccc
	} else {
		die 'QuickBooks Online responded with an error: ' . $response->status_line . "\n" . $response->content;
	}

} elsif ($ARGV[0] eq 'AccessToken') {
	# OAuth Leg #3 - Get the Access Token from QBO.
	my $response = SendOAuthRequest('AccessToken',
		consumer_key           => $consumer_key,
		consumer_secret        => $consumer_secret,
		request_token          => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', # paste in the value from 'oauth_token' from the URL that Intuit redirected you to in OAuth Leg #2
		request_token_secret   => 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',         # paste in the value from 'request_token_secret' that was printed out in OAuth Leg #1
		request_token_verifier => 'ccccccc',                                          # paste in the value from 'oauth_verifier' from the URL that Intuit redirected you to in OAuth Leg #2
	);
	if ($response->is_success) {
		my %vals = map {split(/=/,$_)} split(/&/,$response->decoded_content);
		print 'access_token        = ' . $vals{oauth_token}        . "\n"; # copy this value into the API call in the code block below
		print 'access_token_secret = ' . $vals{oauth_token_secret} . "\n"; # copy this value into the API call in the code block below
	} else {
		say $response->status_line . "\ncontent: " . $response->content;
	}

} elsif ($ARGV[0] eq 'API') {
	# Now that we have the Access Token, we may now make an actual API call to QuickBooks Online.
	my $response = SendOAuthRequest('API',
		consumer_key        => $consumer_key,
		consumer_secret     => $consumer_secret,
		access_token        => 'dddddddddddddddddddddddddddddddddddddddddddddddd', # paste in the value from 'access_token'        that was printed out in OAuth Leg #3 above
		access_token_secret => 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',         # paste in the value from 'access_token_secret' that was printed out in OAuth Leg #3 above
		url_path            => 'query',        # change this to whatever QBO API path you want to access
		url_params          => {
			query => 'Select * from Customer', # insert the name/value pairs here that you want to pass in your API call to QBO
		},
	);
	if ($response->is_success) {
		if (valid_json($response->decoded_content)) {
			my $hash = json_to_perl($response->decoded_content);
			print Dumper($hash) . "\n"; # this should contain the
		} else {
			die 'QuickBooks Online responded with unparsable JSON data: ' . $response->decoded_content;
		}
	} else {
		die 'QuickBooks Online responded with an error: ' . $response->status_line . "\n" . $response->content;
	}
}

sub SendOAuthRequest {
	my($type,%args) = @_;

	my $request;
	my($time,$nonce) = (time(),Data::UUID->new->create_str);
	if ($type eq 'RequestToken') {
		my $hmac = Digest::HMAC_SHA1->new($args{consumer_secret} . '&');
		$hmac->add('GET&' . uri_escape('https://oauth.intuit.com/oauth/v1/get_request_token') . '&' . uri_escape('oauth_callback=' . uri_escape($args{callback}) . '&oauth_consumer_key=' . $args{consumer_key} . '&oauth_nonce=' . $nonce . '&oauth_signature_method=HMAC-SHA1&oauth_timestamp=' . $time . '&oauth_version=1.0'));

		$request = HTTP::Request->new('GET','https://oauth.intuit.com/oauth/v1/get_request_token');
		$request->header(Accept => 'application/json'); # change this to application/xml if that's what you want back
		$request->header(Authorization =>
			'OAuth oauth_callback="' . uri_escape($args{callback})
			. '",oauth_consumer_key="' . $args{consumer_key}
			. '",oauth_nonce="' . $nonce
			. '",oauth_signature="' . uri_escape(encode_base64($hmac->digest))
			. '",oauth_signature_method="HMAC-SHA1'
			. '",oauth_timestamp="' . $time
			. '",oauth_version="1.0'
			. '"');

	} elsif ($type eq 'AccessToken') {
		my $hmac = Digest::HMAC_SHA1->new($args{consumer_secret} . '&' . $args{request_token_secret});
		$hmac->add('GET&' . uri_escape('https://oauth.intuit.com/oauth/v1/get_access_token') . '&' . uri_escape('oauth_consumer_key=' . $args{consumer_key} . '&oauth_nonce=' . $nonce . '&oauth_signature_method=HMAC-SHA1&oauth_timestamp=' . $time . '&oauth_token=' . $args{request_token} . '&oauth_verifier=' . $args{request_token_verifier} . '&oauth_version=1.0'));

		$request = HTTP::Request->new('GET','https://oauth.intuit.com/oauth/v1/get_access_token');
		$request->header(Accept => 'application/json'); # change this to application/xml if that's what you want back
		$request->header(Authorization =>
			'OAuth oauth_consumer_key="' . $args{consumer_key}
			. '",oauth_nonce="' . $nonce
			. '",oauth_signature_method="HMAC-SHA1'
			. '",oauth_timestamp="' . $time
			. '",oauth_token="' . $args{request_token}
			. '",oauth_verifier="' . $args{request_token_verifier}
			. '",oauth_version="1.0'
			. '",oauth_signature="' . uri_escape(encode_base64($hmac->digest))
			. '"');

	} elsif ($type eq 'API') {
		my $hmac = Digest::HMAC_SHA1->new($args{consumer_secret} . '&' . $args{access_token_secret});
		$hmac->add('GET&' . uri_escape('https://sandbox-quickbooks.api.intuit.com/v3/company/' . $company_id . '/' . $args{url_path}) . '&' . uri_escape('oauth_consumer_key=' . $args{consumer_key} . '&oauth_nonce=' . $nonce . '&oauth_signature_method=HMAC-SHA1&oauth_timestamp=' . $time . '&oauth_token=' . $args{access_token} . '&oauth_version=1.0' . '&' . join('&',map {$_ . '=' . uri_escape($args{url_params}->{$_})} sort keys %{$args{url_params}})));

		$request = HTTP::Request->new('GET','https://sandbox-quickbooks.api.intuit.com/v3/company/' . $company_id . '/' . $args{url_path} . '?' . join('&',map {$_ . '=' . $args{url_params}->{$_}} sort keys %{$args{url_params}}));
		$request->header(Accept => 'application/json'); # change this to application/xml if that's what you want back
		$request->header(Authorization =>
			'OAuth oauth_consumer_key="' . $args{consumer_key}
			. '",oauth_nonce="' . $nonce
			. '",oauth_signature="' . uri_escape(encode_base64($hmac->digest))
			. '",oauth_signature_method="HMAC-SHA1'
			. '",oauth_timestamp="' . $time
			. '",oauth_token="' . $args{access_token}
			. '",oauth_version="1.0'
			. '"');
	}
	return LWP::UserAgent->new->request($request);
}
