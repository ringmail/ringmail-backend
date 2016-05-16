package Ring::Twilio;
use strict;
use warnings;

use vars qw();

use Moose;
use Note::Param;
use POSIX 'strftime';
use LWP::UserAgent;
use JSON::XS;

use Note::Param;

no warnings qw(uninitialized);

has 'config' => (
	'is' => 'rw',
	'isa' => 'HashRef',
	'default' => sub {
		my $cfg = $main::note_config->config_apps()->{'ringmail'};
		return {
			'AccountSid' => $cfg->{'twilio_account_sid'},
			'AuthToken' => $cfg->{'twilio_auth_token'},
		};
	},
);

sub send_sms
{
	my ($obj, $param) = get_param(@_);
	my $ua = new LWP::UserAgent();
	my $cfg = $obj->config();
	my $url = 'https://api.twilio.com/2010-04-01/Accounts/'. $cfg->{'AccountSid'};
	$url .= '/Messages.json';
	::log("SMS Send", $param);
	$ua->add_handler('request_prepare' => sub {
		my($request, $ua, $h) = @_;
		$request->authorization_basic($cfg->{'AccountSid'}, $cfg->{'AuthToken'});
	}, 'm_method' => 'POST');
	my $rsp = $ua->post($url, {
		'From' => $param->{'from'},
		'To' => $param->{'to'},
		'Body' => $param->{'body'},
	});
	if ($rsp->is_success())	
	{
		my $json = $rsp->content();
		my $data = undef;
		eval {
			$data = decode_json($json);
		};
		if ($@)
		{
			return {
				'ok' => 0,
				'error' => "JSON Decode Failed: $@",
			};
		}
		::log("SMS Reply", $data);
		return {
			'ok' => 1,
			'twilio_reply' => $data,
		};
	}
	else
	{
		return {
			'ok' => 0,
			'error' => $rsp->status_line(),
		};
	}
}

1;

