#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;
no warnings qw(uninitialized);

use AnyEvent;
use Data::Dumper;
use AnyEvent::RabbitMQ;
use Storable 'nfreeze';
use Config::General;
use JSON::XS;
use Net::RabbitMQ;
use POSIX 'strftime';
use Email::Valid;
use URI::Encode 'uri_decode';

use Ring::API;

$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
require Note::Config;
$main::note_config = $Note::Config::Data;
use Note::Row;
$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

use Ring::Route;
use Ring::User;
use Note::SQL::Table 'sqltable';

my $ar;
my $cv = AnyEvent->condvar();
my $channel;
my $rabbithost = 'localhost';
my $rabbituser = 'guest';
my $rabbitpass = 'guest';
my $rabbitport = 5673;

$SIG{'CHLD'} = 'IGNORE';

my @actions;
my @rqactions;
my %events;
my $x; 
my $do_next = sub {
	my $sr = shift @actions;
	unless (defined $sr)
	{
		return;
	}
	$x++;
	$sr->(@_);
};

sub send_reply
{   
	my ($data) = @_;
	my $st = strftime("%F %T", localtime());
	print "$st ($$) Event Reply: $data->{'uuid'}\n";
	print "Sent: ". Dumper($data);
	my $host = $data->{'queuehost'};
	delete $data->{'queuehost'};
	my $rbq = new Net::RabbitMQ();
	$rbq->connect($rabbithost, {'user' => $rabbituser, 'password' => $rabbitpass, 'port' => $rabbitport});
	$rbq->channel_open(1);
	my $json = encode_json(['event_reply', $data]);
	$rbq->publish(1, 'rgm_'. $host, $json, {'exchange' => 'ringmail'});
	$rbq->disconnect();
}

%events = (
	'target_public' => sub {
		my ($data) = @_;
		print Dumper($data);
	},
	'target_lookup' => sub {
		my ($data) = @_;
		print Dumper($data);
		my $router = new Ring::Route();
#		if ($data->{'target'} eq '1')
#		{
#			send_reply({
#				'uuid' => $data->{'uuid'},
#				'queuehost' => $router->get_queue_host($data->{'hostname'}),
#				'command' => encode_json({
#					'pstn' => '+18883104474',
#				}),
#			});
#			return;
#		}
#		elsif ($data->{'target'} eq '2')
#		{
#			$data->{'target'} = 'mike@dyl.com';
#		}
		my $res = Ring::API->cmd(
			'path' => ['route', 'call'],
			'data' => $data,
		);
		send_reply({
			'uuid' => $data->{'uuid'},
			'queuehost' => $router->get_queue_host($data->{'hostname'}),
			%$res,
		});
	},
	'chat_in' => sub {
		my ($data) = @_;
		print Dumper($data);
		my $res = Ring::API->cmd(
			'path' => ['route', 'chat'],
			'data' => $data,
		);
		unless ($res->{'ok'})
		{
			::_log($res);
		}
	},
	'register_server' => sub {
		my ($data) = @_;
		my $router = new Ring::Route();
		print Dumper($data);
		$router->register_server($data);
	},
	'originate' => sub { # originate result
		my ($data) = @_;
		print Dumper($data);
		if ($data->{'local'})
		{
			my $res = Ring::API->cmd(
				'path' => ['route', 'logger', 'call_update'],
				'data' => {
					'route_id' => $data->{'route_id'},
					'uuid' => $data->{'uuid'},
					'result' => 'originate',
				},
			);
			unless ($res->{'ok'})
			{
				print Dumper($res);
			}
		}
	},
	'hangup' => sub {
		my ($data) = @_;
		print Dumper($data);
		if ($data->{'local'})
		{
			my $res = Ring::API->cmd(
				'path' => ['route', 'logger', 'call_update'],
				'data' => {
					'route_id' => $data->{'route_id'},
					'cause' => $data->{'cause'},
					'result' => 'hangup',
				},
			);
			unless ($res->{'ok'})
			{
				print Dumper($res);
			}
		}
	},
	'bridge' => sub {
		my ($data) = @_;
		print Dumper($data);
		if ($data->{'local'})
		{
			my $res = Ring::API->cmd(
				'path' => ['route', 'logger', 'call_update'],
				'data' => {
					'route_id' => $data->{'route_id'},
					'result' => 'bridged',
				},
			);
			unless ($res->{'ok'})
			{
				print Dumper($res);
			}
		}
	},
	'register' => sub {
		my ($data) = @_;
		print Dumper($data);
		my $contact = $data->{'contact'};
		my $msg = {};
		if ($contact =~ /app\-id\=([\w\.]+)\;/)
		{
			$msg->{'app-id'} = $1;
			foreach my $k (qw/pn-type pn-tok pn-msg-str pn-call-str pn-call-snd/)
			{
				my $mk = quotemeta($k);
				if ($contact =~ /$mk\=(.*?)\;/)
				{
					$msg->{$k} = $1;
				}
			}
		}
		if (scalar keys %$msg)
		{
			#print 'Push Data: '. Dumper($msg);
			if ($data->{'user'} =~ /\%40/)
			{
				my $user = $data->{'user'};
				$user =~ s/\%40/@/;
				my $rc = new Note::Row('ring_user' => {'login' => $user});
				if ($rc->id())
				{
					# check for push pending
					my $crec = new Note::Row('ring_user_push_call' => {
						'call_user_id' => $rc->id(),
						'ts' => ['>=', strftime("%F %T", localtime(time() - 45))],
					});
					if ($crec->id())
					{
						my $cdata = $crec->data();
						my $router = new Ring::Route();
						my $fsroute = $router->get_route_fs({
							'route_type' => 'app',
							'user_id' => $cdata->{'call_user_id'},
						}, $data->{'host'});
						send_reply({
							'uuid' => $cdata->{'call_uuid'},
							'queuehost' => $router->get_queue_host($cdata->{'call_host'}),
							'route' => $fsroute,
							'push' => $crec->id(),
							'ok' => 1,
						});
						$crec->delete();
					}
					# update push token
					my $create = 0;
					my $prod = ($msg->{'app-id'} =~ /\.prod$/) ? 1 : 0;
					my $tokrc = Note::Row::find_create('ring_user_push', {
						'user_id' => $rc->id(),
						'push_type' => 'apple',
					}, {
						'apns_token' => $msg->{'pn-tok'},
						'production' => $prod,
					}, \$create);
					if (! $create)
					{
						if ($tokrc->data('apns_token') ne $msg->{'pn-tok'})
						{
							$tokrc->update({
								'apns_token' => $msg->{'pn-tok'},
								'production' => $prod,
							});
						}
					}
					sqltable('ring_user_push')->delete(
						'where' => {
							'user_id' => ['!=', $rc->id()],
							'apns_token' => $msg->{'pn-tok'},
						},
					);
				}
			}
		}
	},
	'chat_result' => sub {
		my ($data) = @_;
		print Dumper($data);
		my $res = Ring::API->cmd(
			'path' => ['route', 'logger', 'chat_update'],
			'data' => {
				'chat_id' => $data->{'id'},
				'code' => $data->{'code'},
			},
		);
		unless ($res->{'ok'})
		{
			print Dumper($res);
		}
	},
	'cmd_result' => sub {
		my ($data) = @_;
		print Dumper($data);
		return unless (defined $data->{'command'});
		my $res = Ring::API->cmd(
			'path' => ['route', 'logger', 'command_result'],
			'data' => {
				'command' => $data->{'command'},
				'code' => $data->{'code'},
			},
		);
		unless ($res->{'ok'})
		{
			print Dumper($res);
		}
	},
	'push_call' => sub {
		my ($data) = @_;
		print 'Push Call: '. Dumper($data);
		my $router = new Ring::Route();
		my $res = Ring::API->cmd(
			'path' => ['route', 'push', 'call'],
			'data' => {
				'user_id' => $data->{'user_id'},
				'caller_id' => uri_decode($data->{'caller_id'}),
				'uuid' => $data->{'uuid'},
				'hostname' => $data->{'hostname'},
				'reply' => sub {
					my ($ok) = @_;
					send_reply({
						'uuid' => $data->{'uuid'},
						'queuehost' => $router->get_queue_host($data->{'hostname'}),
						'ok' => $ok,
					}),
				},
			},
		);
	},
#	'push_call_ack' => sub {
#		my ($data) = @_;
#		print 'Push Call Ack: '. Dumper($data);
#		my $ck = $data->{'call_key'};
#		if (length($ck) == 32)
#		{
#			my $crec = new Note::Row('ring_user_push_call' => {
#				'call_key' => $ck,
#			});
#			if ($crec->id())
#			{
#				my $cdata = $crec->data();
#				my $router = new Ring::Route();
#				my $fsroute = $router->get_route_fs({
#					'route_type' => 'app',
#					'user_id' => $cdata->{'call_user_id'},
#				}, $data->{'hostname'});
#				send_reply({
#					'uuid' => $cdata->{'call_uuid'},
#					'queuehost' => $router->get_queue_host($cdata->{'call_host'}),
#					'route' => $fsroute,
#					'push' => $crec->id(),
#					'ok' => 1,
#				});
#				$crec->delete();
#				return;
#			}
#		}
#	},
);

@actions = (
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
			print "Connected to RabbitMQ: $rabbithost\n";
		};
		$connectfn->();
	},
);

@rqactions = (
	sub {
		$ar->open_channel(
			on_success => $do_next,
			on_failure => sub { die('open channel'); $cv },
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
		#$do_next->();
	},
	sub {
		$channel->declare_queue(
			'queue' => 'rgm_core',
			'exchange' => 'ringmail',
			'on_success' => $do_next,
			'on_failure' => $cv,
			'no_ack' => 0,
		),
	},
	sub {
		$channel->bind_queue(
			'queue' => 'rgm_core',
			'exchange' => 'ringmail',
			'on_success' => $do_next,
			'on_failure' => $cv,
			'routing_key' => 'rgm_dialer',
		),
	},
	sub {
		$channel->consume(
			'queue' => 'rgm_core',
			'on_success' => $do_next,
			'on_failure' => $cv,
			'on_consume' => sub {
				my $rsp = shift;
				my $body = $rsp->{'body'}->payload();
				my $req = decode_json($body);
				my $evt = $req->[0];
				my $data = $req->[1];
				my $st = strftime("%F %T", localtime());
				print "$st ($$) Queue: $evt\n";
				#print Dumper($data);
				if (exists $events{$evt})
				{
					eval {
						$events{$evt}->($data);
					};
					if ($@)
					{
						my $err = $@;
						::_errorlog("Event Error: $err");
					}
				}
				$channel->ack();
			},
			'no_ack' => 0,
		),
	},
);
push @actions, @rqactions;

foreach my $i (1..2)
{
	if (dofork())
	{
		my $st = strftime("%F %T", localtime());
		print "$st ($$) Forked $i\n";
		$do_next->();
		$cv->recv();
		doexit();
	}
}

while (1)
{
	sleep(20);
#	my $st = strftime("%F %T", localtime());
#	print "$st ($$) Heartbeat\n";
}

sub dofork
{
	my ($nofork) = @_;
	unless ($nofork)
	{
		unless (fork())
		{
			return 1;
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return 1;
	}
}

sub doexit
{
	my ($nofork) = @_;
	unless ($nofork)
	{
		exit(0);
	}
}

