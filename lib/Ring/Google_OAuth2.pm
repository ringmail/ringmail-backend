package Ring::Google_OAuth2;
use strict;
use warnings;

use vars qw();

use Moose;
use LWP::UserAgent;
use JSON::XS 'decode_json';

use Note::Param;

no warnings qw(uninitialized);

# Google App: RingMail-Dev-IOS,  Client ID: 224803357623-b9n16dqjn97ovbuo3v00kflvc0h6tsd5.apps.googleusercontent.com

sub get_token_info
{
	my ($obj, $param) = get_param(@_);
	my $ua = new LWP::UserAgent();
	my $resp = $ua->get('https://www.googleapis.com/oauth2/v3/tokeninfo?id_token='. $param->{'token'});
	if ($resp->is_success())
	{
		my $response = decode_json($resp->content());
		::log('Google OAuth2', $response);
		if ($response->{"aud"} eq "224803357623-b9n16dqjn97ovbuo3v00kflvc0h6tsd5.apps.googleusercontent.com")
		{
			return $response;
		}
	}
	return undef;
}

1;

