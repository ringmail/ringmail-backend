#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(uninitialized);
our $session;
our $env;

package Target;
use strict;
use warnings;

use MIME::Base64;
use JSON::XS;
use Net::RabbitMQ;
use Data::Dumper;
use Digest::MD5 'md5_hex';
use IO::All;
use URI::Encode 'uri_encode', 'uri_decode';
use LWP::UserAgent;

sub new
{
	my ($class) = @_;
	#$session->setVariable('rgm_request', $data->{'request'});
	my $uuid = $session->getVariable('uuid');
	my $data = {};
	$data->{'uuid'} = $uuid;
	$data->{'hostname'} = 'localhost';
#	open(F, '/usr/local/freeswitch/scripts/config.njs') or do {
#		freeswitch::consoleLog("ERR", "Error[$uuid]: Unable to open config file: $!\n");
#		goto DONE;
#	};
#	local $/;
#	my $cfg = <F>;
#	close(F);
	freeswitch::consoleLog("INFO", "Start[$uuid]: ". Dumper($data));
#	$data->{'config'} = decode_json($cfg);
	bless $data, $class;
	return $data;
}

sub lookup
{
	my ($obj) = @_;

	my $api = new freeswitch::API;
	my $res = $api->executeString("uuid_dump $obj->{'uuid'}");
	freeswitch::consoleLog("INFO", "Dump[$obj->{'uuid'}]: $res\n");
	
	my $tgt = $session->getVariable('destination_number');
	$session->setVariable('rgm_reply', '');
	my $ph = $session->getVariable('user_name');
	$ph ||= $session->getVariable('rdnis');
	$obj->send_event('target_lookup', {
		'phone' => $ph,
		'target' => $tgt,
	});
	my $reply = $obj->reply_wait(5);
	my $route = $reply->{'route'};
	if ($route)
	{
		$session->setVariable('instant_ringback', 'true');
		$session->setVariable('continue_on_fail', 'false');
		$session->setVariable('hangup_after_bridge', 'true');
		$session->setVariable('call_timeout', '45');
		$session->setVariable('transfer_ringback', '%(2000,4000,440,480)');
		my $from = uri_encode($reply->{'from_email'}, {'encode_reserved' => 1});
		freeswitch::consoleLog("INFO", "CallerID[$obj->{'uuid'}]: $from\n");
		freeswitch::consoleLog("INFO", "Route[$obj->{'uuid'}]: $route\n");
		$session->execute('bridge', "{origination_caller_id_name='$from',sip_invite_from_uri='<sip:$from\@sip.ringmail.com>'}". $route);
	}
	elsif ($reply->{'error'})
	{
		$session->execute('answer');
		$obj->say($reply->{'error'});
	}
	else
	{
		$session->execute('answer');
		$obj->say('sorry, we were unable to connect your call. please try again later.');
	}
	freeswitch::consoleLog("INFO", "End[$obj->{'uuid'}]\n");
}

sub send_event
{
	my ($obj, $event, $data) = @_;
	freeswitch::consoleLog("INFO", "Target[$obj->{'uuid'}]: Send Event: $event\n");
	#freeswitch::consoleLog("INFO", "Target[$obj->{'uuid'}]: Send Event: $event ". Dumper($data));
	unless (defined $obj->{'rabbitmq'})
	{
		#my $rbcfg = $obj->{'config'}->{'rabbitmq'};
		my $rbcfg = {
			'host' => 'localhost',
			'user' => 'guest',
			'password' => 'guest',
			'port' => 5673,
		};
		$obj->{'rabbitmq'} = new Net::RabbitMQ();
		$obj->{'rabbitmq'}->connect($rbcfg->{'host'}, {'user' => $rbcfg->{'user'}, 'password' => $rbcfg->{'password'}, 'port' => $rbcfg->{'port'}});
		$obj->{'rabbitmq'}->channel_open(1);
	}
	my $rbq = $obj->{'rabbitmq'};
	$data->{'uuid'} = $obj->{'uuid'};
	$data->{'hostname'} = $obj->{'hostname'};
	my $json = encode_json([$event, $data]);
	$rbq->publish(1, 'rgm_dialer', $json, {'exchange' => 'ringmail'});
}

sub reply_wait
{
	my ($obj, $secs, $loopfn) = @_;
	my $r = '';
	LOOP: foreach my $i (1..$secs)
	{
		foreach my $j (1..4)
		{
			exit_on_hangup();
			$session->execute('sleep', '250');
			$r = $session->getVariable('rgm_reply');
			if (length($r))
			{
				last LOOP;
			}
		}
		if (defined($loopfn) && ref($loopfn) eq 'CODE')
		{
			$loopfn->($obj, $secs, $i);
		}
	}
	my $data = undef;
	unless (length($r))
	{
		freeswitch::consoleLog("INFO", "Target[$obj->{'uuid'}]: Empty Reply\n");
	}
	eval {
		$data = decode_json(decode_base64($r));
	};
	unless (defined $data)
	{
		freeswitch::consoleLog("INFO", "Target[$obj->{'uuid'}]: Bad Reply\n");
		#warn("Bad reply data: $@");
		return undef;
	}
	#else
	#{
	#	freeswitch::consoleLog("INFO", "Target[$obj->{'uuid'}]: Got Reply: ". Dumper($data));
	#}
	return $data;
}

sub exit_on_hangup
{
	my $st = $session->getState();
	if ($st eq 'CS_HANGUP')
	{
		goto DONE;
	}
}

sub say_google
{
	my ($obj, $msg) = @_;
	my $md5 = md5_hex($msg);
	my $root = '/usr/local/freeswitch/sounds/en/us/callie/tts';
	mkdir($root) unless (-d $root);
	my $fp = $root. '/'. $md5. '.mp3';
	unless (-e $fp)
	{
		my $url = 'http://translate.google.com/translate_tts?tl=en&q='. uri_encode($msg);
		freeswitch::consoleLog("INFO", "Get $url -> $fp\n");
		my $ua = new LWP::UserAgent(
			'agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.6) Gecko/2009011912 Firefox/3.0.6',
		);
		my $r = $ua->get($url);
		if ($r->is_success())
		{
			$r->content() > io($fp);
			freeswitch::consoleLog("INFO", "Convert $fp\n");
			my $wav = $fp;
			$wav =~ s/mp3$/wav/;
			my $wavtmp = $wav;
			$wavtmp =~ s/\.wav$/_tmp.wav/;
			my $wav2 = $wav;
			$wav2 =~ s/\.wav$/_16.wav/;
			system('/usr/local/bin/lame', '--decode', $fp, $wavtmp);
			system('/usr/bin/sox', $wavtmp, '-c', 1, '-r', 8000, $wav);
			system('/usr/bin/sox', $wavtmp, '-c', 1, '-r', 16000, $wav2);
			unlink($wavtmp);
		}
	}
	my $w2 = '';
	my $ci = $session->getVariable('read_codec');
	if ($ci ne 'PCMU')
	{
		$w2 = '_16';
	}
	my $play = 'tts/'. $md5. $w2. '.wav';
	$session->execute('playback', $play);
}

sub say
{
	my ($obj, $msg) = @_;
	$obj->say_google($msg);
	#$session->execute('speak', 'flite|kal|'. $msg);
}

1;

package main;

my $d = new Target();
$d->lookup();

DONE:

if (defined $d->{'rabbitmq'})
{
	$d->{'rabbitmq'}->disconnect();
}

1;

