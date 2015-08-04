#!/usr/bin/perl5.10.1
use strict;
use warnings;
no warnings 'uninitialized';

use Carp::Always;
use Data::Dumper;
use AnyEvent::FreeSWITCH;
use AnyEvent::RabbitMQ;
use Storable 'nfreeze';
use POSIX 'strftime';
use JSON::XS;
use MIME::Base64;
use Net::RabbitMQ;

$SIG{'CHLD'} = 'IGNORE';

#$Object::Event::DEBUG = 2;

#open(F, '/usr/local/freeswitch/scripts/config.njs') or die("Unable to open config file: $!\n");
#local $/;
#my $cfg = <F>;
#close(F);
#my $obj = {};
#$obj->{'config'} = decode_json($cfg);

my %events = ();

my $rabbithost = 'localhost';
my $rabbituser = 'guest';
my $rabbitpass = 'guest';
my $rabbitport = 5673;

my $host = $ARGV[0];
$host ||= 'localhost'; # staging
unless (defined $host)
{
	print "Unknown Server\n";
	exit(1);
}
my $fspass = '9032dncw8xb2e6dn7';
my $fsport = '8021';
my @actions;
my @rqactions;
my $do_next = sub {
	my $sr = shift @actions;
	return unless (defined $sr);
	$sr->(@_);
};

my $ar;
my $cv = AnyEvent->condvar;
my $channel;
my $aefs = undef;

$SIG{INT} = sub {
	if (defined $aefs)
	{
		if (defined $aefs->{'esl'})
		{
			if ($aefs->{'esl'}->connected())
			{
				print "Disconnecting from Freeswitch\n";
				$aefs->{'esl'}->disconnect();
			}
		}
	}
	exit(0);
};

%events = (
	'queue_msg' => sub {
		my ($obj, $body) = @_;
		my $req = decode_json($body);
		my $evt = $req->[0];
		my $data = $req->[1];
		my $st = strftime("%F %T", localtime());
		print "$st Queue: $evt\n";
		#print Dumper($data);
		#print "$evt ". Dumper($data);
		if (exists $events{'queue'}->{$evt})
		{
			$events{'queue'}->{$evt}->($data);
		}
	},
	'connected' => sub {
		my ($obj) = @_;
		print "Connected to FreeSWITCH\n";
	},
	'error_connection' => sub {
		my ($obj) = shift;
		print "Error connecting to FreeSWITCH: $!\n";
	},
	'recv_event' => sub {
		my ($obj, $evt, $json) = @_;
		my $data = decode_json($json);
		my $st = strftime("%F %T", localtime());
		print "$st Freeswitch: $evt\n";
		#print "Freeswitch: $evt\n" unless ($evt eq 'CUSTOM' && $data->{'Event-Subclass'} =~ /sofia\:\:register/);
		#print "$evt ". Dumper($data);
		if (exists $events{'freeswitch'}->{lc($evt)})
		{
			$events{'freeswitch'}->{lc($evt)}->($data);
		}
	},
	'queue' => {
		'did_prompt' => sub {
			my ($data) = @_;
			unless (defined $aefs)
			{
				warn('No Freeswitch listener');
				return;
			}
			unless ($aefs->is_connected())
			{
				warn('Freeswitch not connected');
				return;
			}
			#print Dumper($data);
			$data->{'hostname'} = $host;
			my $dataenc = encode_base64(encode_json($data), '');
			my $gw = 'sofia/gateway/flowroute/1'. $data->{'did_number'};
			my $cid = '+18880001234';
			my $orig = "{originate_timeout=30,origination_caller_id_number=$cid,ignore_early_media=true,rgm_data='$dataenc'}$gw loopback/ringmail_dialer";
			#print("Orig: $orig\n");
			$aefs->{'esl'}->bgapi('originate', $orig);
		},
		'event_reply' => sub {
			my ($data) = @_;
			unless (defined $aefs)
			{
				warn('No Freeswitch listener');
				return;
			}
			unless ($aefs->is_connected())
			{
				warn('Freeswitch not connected');
				return;
			}
			my $uuid = $data->{'uuid'};
			my $dataenc = encode_base64(encode_json($data), '');
			$aefs->{'esl'}->bgapi('uuid_setvar', "$uuid rgm_reply $dataenc");
			print Dumper($data);
		},
	},
	'freeswitch' => {
		'background_job' => sub {
			my ($data) = @_;
			if ($data->{'Job-Command'} eq 'originate')
			{
				my $body = $data->{'_body'};
				if ($body =~ s/^\-ERR (.+)$//)
				{
					my $err = $1;
					my $cmd = $data->{'Job-Command-Arg'};
					if ($cmd =~ /ringmail_dialer$/)
					{
						my $rqid = $1;
						my %rc = (
							'request' => $rqid,
							'cause' => $err,
						);
						print("Originate Failed: ", Dumper(\%rc));
						#$channel->publish(
						#	'exchange' => 'ringmail',
						#	'routing_key' => 'rgm_dialer',
						#	'body' => encode_json(['hangup_originate', \%rc]),
						#);
					}
				}
			}
		},
		'message' => sub {
			my ($data) = @_;
			print Dumper($data);
		},
	},
);

@actions = (
	sub {
		$aefs = new AnyEvent::FreeSWITCH(
			#'host' => $host,
			'host' => $ARGV[1] || '127.0.0.1',
			'port' => $fsport,
			'password' => $fspass,
			'events' => 'HEARTBEAT BACKGROUND_JOB MESSAGE',
		);
		foreach my $k (keys %events)
		{
			next if ($k eq 'freeswitch' || $k eq 'queue');
			$aefs->reg_cb($k, $events{$k});
		}
		$aefs->connect();
		$do_next->();
	},
	sub {
		my $connectfn;
		my $closefn = sub {
			#my $method_frame = shift->method_frame;
			#die $method_frame->reply_code, $method_frame->reply_text;
			print "RabbitMQ Connection Closed\n";
			@actions = @rqactions;
			$connectfn->();
		};
		$connectfn = sub {
			$ar = AnyEvent::RabbitMQ->new->load_xml_spec()->connect(
				host			 => $rabbithost,
				port			 => $rabbitport,
				user			 => $rabbituser,
				pass			 => $rabbitpass,
				vhost			=> '/',
				timeout		=> 1,
				on_success => $do_next,
				on_failure => $cv,
				on_read_failure => sub {die @_},
				on_close => $closefn,
			);
			print "Connected to RabbitMQ: $host\n";
		};
		$connectfn->();
	},
);

@rqactions = (
	sub {
		$ar->open_channel(
			on_success => $do_next,
			on_failure => $cv,
			on_close => sub {
				my $method_frame = shift->method_frame;
				die $method_frame->reply_code, $method_frame->reply_text;
			}
		);
	},
	sub {
		$channel = shift;
		$channel->declare_exchange(
			exchange => 'ringmail',
			type => 'direct',
			on_success => $do_next,
			on_failure => $cv,
		);
	},
	sub {
		$channel->declare_queue(
			'queue' => 'rgm_dialer_'. $host,
			'exchange' => 'ringmail',
			'on_success' => $do_next,
			'on_failure' => $cv,
		),
	},
	sub {
		$channel->bind_queue(
			'queue' => 'rgm_dialer_'. $host,
			'exchange' => 'ringmail',
			'on_success' => $do_next,
			'on_failure' => $cv,
			'routing_key' => 'rgm_'. $host,
		),
	},
	sub {
		$channel->consume(
			'queue' => 'rgm_dialer_'. $host,
			'on_success' => $do_next,
			'on_failure' => $cv,
			'on_consume' => sub {
				my $rsp = shift;
				my $body = $rsp->{'body'}->payload();
				unless (defined $aefs)
				{
					warn('No Freeswitch handler for message');
					return;
				}
				$aefs->event('queue_msg', $body);
			},
		),
		print "Subscribed to RabbitMQ: $host\n";
	},
);
push @actions, @rqactions;

sub main::errorlog
{
	my (@data) = @_;
	my $log = '';
	foreach my $i (@data)
	{
		if (ref($i))
		{
			$log .= Dumper($i);
		}
		elsif (defined $i)
		{
			$i =~ s/\n$//;
			$log .= "$i\n";
		}
		else
		{
			$log .= "\n";
		}
	}
	eval {
		$::config{'errorlog'} ||= '/tmp/error_log';
		open(F, '>>', $::config{'errorlog'}) or die ($!);
		my $tm = strftime("%F %T", localtime(time()));
		print F "##### $tm #####\n$log";
		close(F);
	};
}

$do_next->();
print $cv->recv, "\n";

