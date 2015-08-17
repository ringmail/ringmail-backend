package Ring::XMLRPC;
use strict;
use warnings;

use Carp::Always;
use Data::Dumper;
use JSON::XS;
use Date::Parse 'str2time';
use POSIX 'strftime';
use Encode 'encode';

use Note::Row;
use Note::SQL::Table;
use Ring::User;
use Ring::API;

use vars qw();

sub main::check_account_with_phone # V2
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	my $phone = shift;
	unless (Email::Valid->address($em))
	{
		return 1; # error
	}
	my $out = Ring::API->cmd(
		'path' => ['user', 'check', 'user'],
		'data' => {
			'email' => $em,
			'phone' => $phone,
		},
	);
#	print STDERR 'Check '. Dumper({
#		'email' => $em,
#		'phone' => $phone,
#	}, $out);
	if ($out->{'ok'})
	{
		return 0;
	}
	else
	{
		return $out->{'error_code'};
	}
	return 0;
}

sub main::check_account # V1
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	unless (Email::Valid->address($em))
	{
		return 1; # error
	}
	my $t = sqltable('ring_user');
	my $c = $t->count('login' => $em);
	if ($c)
	{
		return 1; # error
	}
	return 0;
}

sub main::create_account_with_contacts # V2
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	my $pass = shift;
	my $ua = shift;
	my $phone = shift;
	my $name = shift;
	my $contacts = shift;
	unless (Email::Valid->address($em))
	{
		return 1; # error
	}
	#print STDERR "XMLRPC: create_account_with_contacts ip:$ENV{'REMOTE_ADDR'} email:$em useragent:$ua phone:$phone name:'$name' contacts:$contacts\n";
	my $ctdata = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $contacts);
		$ctdata = JSON->new->utf8->decode($jsonutf8);
	};
	if ($@)
	{
		print STDERR "XMLRPC: create_account_with_contacts ip:$ENV{'REMOTE_ADDR'} email:$em useragent:$ua JSON Error: $@\n";
		return 1;
	}
	my @cts = ();
	my $out;
	if (defined $ctdata)
	{
		my $maxts = 0;
		foreach my $ct (@{$ctdata->{'contacts'}})
		{
			my %rec = (
				'id' => $ct->{'id'},
				'first_name' => $ct->{'fn'},
				'last_name' => $ct->{'ln'},
				'organization' => $ct->{'co'},
				'ts_updated' => str2time($ct->{'ts'}),
				'email' => $ct->{'em'},
				'phone' => $ct->{'ph'},
			);
			push @cts, \%rec;
			#print STDERR Dumper(\%rec);
		}
		$out = Ring::API->cmd(
			'path' => ['user', 'create'],
			'data' => {
				'email' => $em,
				'password' => $pass,
				'password2' => $pass,
				'contacts' => \@cts,
				'phone' => $phone,
				'name' => $name,
				'send_sms' => 1,
			},
		);
		#print STDERR Dumper($ctdata);
		#return 1;
	}
	if ($out->{'ok'})
	{
		return 0; # success
	}
	my $err = Dumper($out->{'errors'});
	print STDERR "XMLRPC: create_account_with_contacts ip:$ENV{'REMOTE_ADDR'} email:$em useragent:$ua Error: $err\n";
	return 1;
}

sub main::validate_phone
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	my $phone = shift;
	my $code = shift;
	$phone =~ s/\D//g;
	$phone =~ s/^1//;
	unless (length($phone) == 10)
	{
		::_errorlog("Error in 'validate_phone': Invalid phone number");
		return 1; # error
	}
	my $urec = new Note::Row(
		'ring_user' => {'login' => $em},
	);
	unless ($urec->id())
	{
		::_errorlog("Error in 'validate_phone': Invalid login");
		return 1; # error
	}
	my $drec = new Note::Row(
		'ring_did' => {
			'did_code' => 1,
			'did_number' => $phone,
		},
	);
	unless ($drec->id())
	{
		::_errorlog("Error in 'validate_phone': Phone number not found");
		return 1; # error
	}
	my $udrec = new Note::Row(
		'ring_user_did' => {
			'user_id' => $urec->id(),
			'did_id' => $drec->id(),
		},
	);
	unless ($udrec->id())
	{
		::_errorlog("Error in 'validate_phone': Phone number not connected to account");
		return 1; # error
	}
	unless ($code =~ /^\d{4}$/)
	{
		::_errorlog("Error in 'validate_phone': Invalid verification code");
		return 1; # error
	}
	my $out = Ring::API->cmd(
		'path' => ['user', 'target', 'verify', 'did', 'check'],
		'data' => {
			'user_id' => $urec->id(),
			'did_id' => $drec->id(),
			'verify_code' => $code,
		},
	);
	if ($out->{'ok'})
	{
		return 0;
	}
	else
	{
		if ($out->{'error'} ne 'Invalid verification code')
		{
			::_errorlog("Error in 'validate_phone': Validation error", $out);
		}
		else
		{
			::_errorlog("Error in 'validate_phone': Validation failed");
		}
		return 1; # error
	}
}

sub main::create_account_with_useragent # V1
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	my $pass = shift;
	my $ua = shift;
	unless (Email::Valid->address($em))
	{
		return 1; # error
	}
	#print STDERR "XMLRPC: create_account_with_useragent ip:$ENV{'REMOTE_ADDR'} email:$em useragent:$ua\n";
	my $out = Ring::API->cmd(
		'path' => ['user', 'create'],
		'data' => {
			'email' => $em,
			'password' => $pass,
			'password2' => $pass,
		},
	);
	if ($out->{'ok'})
	{
		return 0; # success
	}
	my $err = Dumper($out);
	print STDERR "XMLRPC: create_account_with_useragent ip:$ENV{'REMOTE_ADDR'} email:$em useragent:$ua Error: $err\n";
	return 1;
}

sub main::check_account_validated
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $em = shift;
	#print STDERR Dumper({'email' => $em});
	unless (Email::Valid->address($em))
	{
		return 0; # error
	}
	my $rc = new Note::Row('ring_user' => {
		'login' => $em,
		'active' => 1,
		'verified' => 1,
	});
	if ($rc->id())
	{
		return 1; # success
	}
	return 0;
}

sub main::check_sync
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "check_sync: $json\n";
	my $req = undef;
	eval {
		$req = decode_json($json);
	};
	if (defined $req)
	{
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		unless ($valid->{'ok'})
		{
			return 0;
		}
		my $sync = Ring::API->cmd(
			'path' => ['user', 'contact', 'check_sync'],
			'data' => {
				'user_id' => $valid->{'user_id'},
				'ts_updated' => $req->{'ts_update'},
				'item_count' => $req->{'count'},
			},
		);
		#print STDERR "sync check status: ". Dumper($sync);
		if ($sync->{'ok'})
		{
			if ($sync->{'sync'})
			{
				return 2;
			}
			else
			{
				return 1;
			}
		}
	}
	return 0
}

sub main::sync_contacts
{
    my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "sync_contacts: $json\n";
	my $req = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $json);
		$req = JSON->new->utf8->decode($jsonutf8);
	};
	#print STDERR Dumper("sync_contacts_data:", $req, $@);
	if (defined $req)
	{
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		unless ($valid->{'ok'})
		{
			return 0;
		}
		my $sync = Ring::API->cmd(
			'path' => ['user', 'contact', 'sync'],
			'data' => {
				'user_id' => $valid->{'user_id'},
				'contacts' => $req->{'contacts'},
			},
		);
		#print STDERR "sync status: ". Dumper($sync);
	}
	return 1;
}

sub main::get_remote_data
{
	my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "get_remote_data: $json\n";
	my $req = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $json);
		$req = JSON->new->utf8->decode($jsonutf8);
	};
	if (defined $req)
	{
		my %resdata = ();
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		if ($valid->{'ok'})
		{
			my $uid = $valid->{'user_id'};
			my $cts = $req->{'contacts'};
			if (defined($cts) && scalar(@$cts) == 0) # update all
			{
				my $rginfo = Ring::API->cmd(
					'path' => ['user', 'contact', 'uri'],
					'data' => {
						'user_id' => $uid,
						'contacts' => $cts,
					},
				);
				$resdata{'ringmail'} = $rginfo->{'data'};
			}
			# update favorites
			my $sendfavs = 1;
			my $summ = new Note::Row(
				'ring_contact_summary' => {
					'user_id' => $uid,
				},
				{
					'select' => ['ts_favorites'],
				}
			);
			if ($summ->id())
			{
				my $loadfavs = 0;
				if (defined $summ->data('ts_favorites'))
				{
					my $tsu = str2time($summ->data('ts_favorites'). 'Z');
					if (defined $req->{'favorites_ts'})
					{
						my $clientts = str2time($req->{'favorites_ts'});
						if ($tsu == $clientts) # client and server are the same timestamp
						{
							$sendfavs = 0;
						}
						else
						{
							if ($clientts > $tsu) # client is newer
							{
								$summ->update({'ts_favorites' => strftime("%F %T", gmtime($clientts))});
								$loadfavs = 1;
								$sendfavs = 0;
							}
						}
					}	
				}
				elsif (defined $req->{'favorites_ts'})
				{
					my $clientts = str2time($req->{'favorites_ts'});
					$summ->update({'ts_favorites' => strftime("%F %T", gmtime($clientts))});
					$loadfavs = 1;
					$sendfavs = 0;
				}
				if ($loadfavs)
				{
					#::_log("Load Favorites");
					my $ct = sqltable('ring_contact');
					$ct->set(
						'update' => {'favorite' => 0},
						'where' => {
							'user_id' => $uid,
						},
					);
					if (scalar @{$req->{'favorites'}})
					{
						my @appleids = ();
						foreach my $k (@{$req->{'favorites'}})
						{
							if ($k =~ /^\d+$/)
							{
								push @appleids, $k;
							}
						}
						if (scalar @appleids)
						{
							my $ids = join(',', @appleids);
							$ct->set(
								'update' => {'favorite' => 1},
								'where' => [
									{
										'user_id' => $uid,
									},
									'and',
									"apple_id in ($ids)",
								],
							);
						}
					}
				}
				if ($sendfavs && defined $summ->data('ts_favorites'))
				{
					#::_log("Send Favorites");
					my $fq = sqltable('ring_contact')->get(
						'array' => 1,
						'select' => ['apple_id'],
						'where' => {
							'favorite' => 1,
							'user_id' => $uid,
						},
					);
					$resdata{'favorites'} = [map {$_->[0]} @$fq];
					$resdata{'favorites_ts'} = str2time($summ->data('ts_favorites'). 'Z');
				}
			}
		}
		my $reply = JSON->new->utf8->encode(\%resdata);
		#print STDERR "get_remote_data reply: $reply\n";
		return $reply;
	}
	return '';
}

sub main::set_contact
{
	my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "set_contact: $json\n";
	my $req = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $json);
		$req = JSON->new->utf8->decode($jsonutf8);
	};
	if (defined $req)
	{
		my %resdata = ();
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		if ($valid->{'ok'})
		{
			my $uid = $valid->{'user_id'};
			my $cts = $req->{'contact'};
			my $syncinfo = Ring::API->cmd(
				'path' => ['user', 'contact', 'sync'],
				'data' => {
					'user_id' => $uid,
					'apple_id' => $cts->{'id'},
					'contacts' => [$cts],
				},
			);
			my $rginfo = Ring::API->cmd(
				'path' => ['user', 'contact', 'uri'],
				'data' => {
					'user_id' => $uid,
					'contacts' => [$cts],
				},
			);
			$resdata{'ringmail'} = $rginfo->{'data'};
		}
		my $reply = JSON->new->utf8->encode(\%resdata);
		#print STDERR "set_contact reply: $reply\n";
		return $reply;
	}
	return '';
}

sub main::get_chat_messages
{
	my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "get_chat_messages: $json\n";
	my $req = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $json);
		$req = JSON->new->utf8->decode($jsonutf8);
	};
	if (defined $req)
	{
		my %resdata = ();
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		if ($valid->{'ok'})
		{
			my $uid = $valid->{'user_id'};
			my $q = sqltable('ring_chat_log')->get(
				'hash' => 1,
				'select' => [
					'id',
					'ts',
					'(select login from ring_user u where u.id=ring_chat_log.from_user_id) as from_user',
					'message_type',
					'message_body',
					'media_url',
					'uuid',
				],
				'where' => {
					'to_user_id' => $uid,
					'delivered' => 0,
				},
				'order' => 'id desc limit 25',
			);
			my @msgs = ();
			my %fuid = ();
			if (scalar @$q)
			{
				my $ids = join(',', map {$_->{'id'}} @$q);
				sqltable('ring_chat_log')->set(
					'update' => {
						'delivered' => 1,
						'ts_delivered' => strftime("%F %T", gmtime()),
						'delivered_status' => 'http',
					},
					'where' => "id in ($ids)",
				);
				foreach my $r (@$q)
				{
					my $from = $r->{'from_user'};
					$from =~ s/\@/%40/;
					my %rec = (
						'ts' => str2time($r->{'ts'}. 'Z'),
						'from' => "sip:$from\@sip.ringmail.com",
						'uuid' => $r->{'uuid'},
					);
					if ($r->{'message_type'} eq 'image')
					{
						$rec{'img'} = $r->{'media_url'};
					}
					elsif ($r->{'message_type'} eq 'text')
					{
						$rec{'body'} = $r->{'message_body'};
					}
					unshift @msgs, \%rec;
					unless (exists $fuid{$r->{'from_user'}}) # confirmations to send
					{
						$fuid{$r->{'from_user'}} = $r->{'uuid'};
					}
				}
			}
			$resdata{'messages'} = \@msgs;
			# get confirmations not delivered to me
			my $q2 = sqltable('ring_chat_log')->get(
				'hash' => 1,
				'select' => [
					'id',
					'uuid',
				],
				'where' => {
					'from_user_id' => $uid,
					'confirmed' => 0,
					'delivered' => 1,
				},
				'order' => 'id desc limit 50',
			);
			my @cfms = ();
			if (scalar @$q2)
			{
				my $ids = join(',', map {$_->{'id'}} @$q2);
				sqltable('ring_chat_log')->set(
					'update' => {
						'confirmed' => 1,
						'ts_confirmed' => strftime("%F %T", gmtime()),
						'confirmed_status' => 'http',
					},
					'where' => "id in ($ids)",
				);
				foreach my $r (@$q2)
				{
					push @cfms, $r->{'uuid'};
				}
			}
			$resdata{'chat_confirms'} = \@cfms;
			my $router = new Ring::Route();
			foreach my $ext (sort keys %fuid)
			{
				my $uuid = $fuid{$ext};
				$ext =~ s/\@/%40/;
				my $siphost = $router->get_sip_host($ext);
				if (defined $siphost)
				{
					my $qhost = $router->get_random_server();
					my $req = {
						'to' => $ext,
						'proxy' => $siphost,
						'command' => encode_json({
							'chat_delivered' => $uuid,
						}),
						'queuehost' => $qhost,
					};
					$router->send_request('chat_cmd', $req);
				}
			}
		}
		my $reply = JSON->new->encode(\%resdata);
		#print STDERR "get_chat_messages reply: $reply\n";
		return $reply;
	}
	return '';
}

sub main::logout_device
{
	my ($self) = shift;
	return unless (caller() eq 'SOAP::Server');
	main::xmlrpc_setup();
	my $json = shift;
	#print STDERR "logout_device: $json\n";
	my $req = undef;
	eval {
		my $jsonutf8 = encode('UTF-8', $json);
		$req = JSON->new->utf8->decode($jsonutf8);
	};
	if (defined $req)
	{
		my $reply = 0;
		my $valid = Ring::API->cmd(
			'path' => ['user', 'valid'],
			'data' => {
				'login' => $req->{'login'},
				'password' => $req->{'password'},
			},
		);
		if ($valid->{'ok'})
		{
			my $uid = $valid->{'user_id'};
			sqltable('ring_user_push')->delete(
				'where' => {
					'user_id' => $uid,
				},
			);
			$reply = 1;
		}
		#print STDERR "logout_device reply: $reply\n";
		return $reply;
	}
	return '';
}

sub main::xmlrpc_setup
{
	$main::app_config = $main::note_config->{'config_apps'}->{'ringmail'};
	$Note::Row::Database = $main::note_config->{'storage'}->{$main::app_config->{'sql_database'}};
}
 
1;

