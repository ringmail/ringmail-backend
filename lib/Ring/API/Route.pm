package Ring::API::Route;
use strict;
use warnings;

use vars qw();

use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use JSON::XS 'encode_json';
use Digest::MD5 'md5_hex';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::API::Base;
use Ring::User;
use Ring::Route;

use base 'Ring::API::Base';

no warnings qw(uninitialized);

# route a call
sub call
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $ph = $data->{'phone'};
	my $dest = lc($data->{'target'});
	$dest =~ s/\%40/\@/;
	my %res = ();
	my $router = new Ring::Route();
	my $target = $router->get_target_type(
		'target' => $dest,
	);
	unless (defined $target)
	{
		return {'ok' => 0, 'error' => 'Unable to determine target type'};
	}
	my $rt;
	if ($target eq 'email')
	{
		$rt = $router->get_route(
			'target' => 'email',
			'target_email' => $dest,
		);
	}
	elsif ($target eq 'domain')
	{
		$rt = $router->get_route(
			'target' => 'domain',
			'target_domain' => $dest,
		);
	}
	elsif ($target eq 'did')
	{
		$rt = $router->get_route(
			'target' => 'did',
			'target_did' => $dest,
		);
		unless (defined $rt)
		{
			# no DID route found, send to tel: URI
			return {
				'command' => encode_json({
					'pstn' => $dest,
				}),
			};
		}
	}
	my $login = $router->get_login_info(
		'phone' => $ph,
		'source' => $data->{'source'},
	);
	if (defined $rt)
	{
		my $callerid = $login->{'login'};
		my $cinfo = undef;
		if (defined $login->{'login'})
		{
			$cinfo = $router->get_contact_info(
				'user_id' => $rt->{'user_id'},
				'email' => $login->{'login'},
			);
		}
		my %contact = ();
		if (defined $cinfo)
		{
			$callerid = $cinfo->{'name'};
			$contact{'target_contact_id'} = $cinfo->{'id'};
		}
		$rt->{'hostname'} = $data->{'hostname'};
		my $dsthost = undef;
		my $fsroute = $router->get_route_fs($rt, \$dsthost);
		my %codec = ();
		$codec{'ringback'} = 'rgm_ringback_2';
		if ($rt->{'route_type'} eq 'did')
		{
			$codec{'codec'} = 'PCMU';
		}
		elsif ($rt->{'route_type'} eq 'app')
		{
			$codec{'app'} = $rt->{'user_id'};
		}
		my $srchost = $data->{'hostname'};
		$dsthost ||= $srchost;
		my $log = Ring::API->cmd(
			'path' => ['route', 'logger', 'call'],
			'data' => {
				# caller
				'caller_type' => $login->{'type'},
				'caller_user_id' => $login->{'user_id'},
				'caller_phone_id' => $login->{'phone_id'},
				'caller_host' => $srchost,
				'fs_uuid_aleg' => $data->{'uuid'},
				# target
				'target_type' => $target,
				'target_id' => $rt->{'target_id'},
				'target_user_id' => $rt->{'user_id'},
				%contact,
				# route,
				'route_info' => $rt,
				'route_host' => $dsthost,
			},
		);
		if ($log->{'ok'})
		{
			unless (defined $fsroute)
			{
				$res{'error'} = 'That user is not currently online. Please try again later.';
			}
			else
			{
				%res = (
					'ok' => 1,
					'route' => $fsroute,
					'from_contact' => $login->{'login'},
					'from_callerid' => $callerid,
					'route_id' => $log->{'route_id'},
					%codec,
				);
			}
		}
		else
		{
			::_log($log);
			$res{'error'} = 'Sorry, something went wrong.';
		}
	}
	elsif ($target eq 'email')
	{
		my $ob = Ring::User::onboard_email(
			'to' => $dest,
			'from' => $login->{'login'},
		);
		if ($ob->{'sent'})
		{
			$res{'error'} = 'That email address is not registered with ring mail. A message has been sent to help them sign up.';
		}
		elsif ($ob->{'user'})
		{
			$res{'error'} = 'That user is not currently online. Please try again later.';
		}
		else
		{
			$res{'error'} = 'That email address is not registered with ring mail.';
		}
	}
	return \%res;
}

sub logger
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $path = $param->{'path'};
	my $type = shift @$path;
	if ($type eq 'call')
	{
		my $tgtype = $data->{'target_type'};
		unless (
			$tgtype eq 'email' ||
			$tgtype eq 'did' ||
			$tgtype eq 'domain'
		) {
			die(qq|Invalid target type: '$tgtype'|);
		}
		my $shost = new Note::Row('ring_server_voip' => {
			'host_name' => $data->{'caller_host'},
		});
		unless ($shost->{'id'})
		{
			die(qq|Invalid caller host: '$data->{'caller_host'}'|);
		}
		my $dhost = new Note::Row('ring_server_voip' => {
			'host_name' => $data->{'route_host'},
		});
		unless ($dhost->{'id'})
		{
			die(qq|Invalid route host: '$data->{'route_host'}'|);
		}
		my $tgid = $data->{'target_id'};
		my $crec = Note::Row::create('ring_call', {
			# caller
			'fs_server_id' => $shost->{'id'},
			'fs_uuid_aleg' => $data->{'fs_uuid_aleg'},
			'caller_type' => $data->{'caller_type'},
			'caller_phone_id' => $data->{'caller_phone_id'},
			'caller_did_id' => $data->{'caller_did_id'}, # PSTN gateway call
			'caller_user_id' => $data->{'caller_user_id'},
			# target
			'target_id' => $tgid,
			'target_type' => $tgtype,
			'target_user_id' => $data->{'target_user_id'},
			'target_contact_id' => $data->{'target_contact_id'}, # contact may be deleted later
			'ts' => strftime("%F %T", gmtime()),
		});
		my $ri = $data->{'route_info'};
		my $rtrec = Note::Row::create('ring_call_route', {
			'call_id' => $crec->{'id'},
			'fs_server_id' => $dhost->{'id'},
			'ts' => strftime("%F %T", gmtime()),
			'route_did_id' => $ri->{'did_id'},
			'route_phone_id' => $ri->{'phone_id'},
			'route_sip_id' => $ri->{'sip_id'},
			'route_type' => $ri->{'route_type'},
			'result' => 'pending',
		});
		return {
			'ok' => 1,
			'route_id' => $rtrec->{'id'},
		};
	}
	elsif ($type eq 'call_update')
	{
		my $rtrec = new Note::Row('ring_call_route' => {
			'id' => $data->{'route_id'},
		});
		unless ($rtrec->{'id'})
		{
			die(qq|Invalid call route record id: $data->{'route_id'}|);
		}
		if ($data->{'result'} eq 'originate')
		{
			$rtrec->update({
				'fs_uuid_bleg' => $data->{'uuid'},
				'result' => $data->{'result'},
			});
		}
		elsif ($data->{'result'} eq 'bridged')
		{
			$rtrec->update({
				'ts_bridged' => strftime("%F %T", gmtime()),
				'result' => $data->{'result'},
			});
		}
		elsif ($data->{'result'} eq 'hangup')
		{
			$rtrec->update({
				'ts_end' => strftime("%F %T", gmtime()),
				'fs_hangup_cause' => $data->{'cause'},
				'result' => $data->{'result'},
			});
		}
		return {
			'ok' => 1,
		};
	}
	elsif ($type eq 'chat')
	{
		my $chrec = Note::Row::create('ring_chat_log', {
			'ts' => strftime("%F %T", gmtime()),
			'from_user_id' => $data->{'from_user_id'},
			'to_user_id' => $data->{'to_user_id'},
			'target_type' => $data->{'target_type'},
			'target_id' => $data->{'target_id'},
			'message_body' => $data->{'message_body'},
			'message_type' => $data->{'type'},
			'media_url' => $data->{'media_url'},
			'uuid' => $data->{'uuid'},
		});
		return {
			'chat_id' => $chrec->{'id'},
			'ok' => 1,
		};
	}
	elsif ($type eq 'chat_update')
	{
		my $rtrec = new Note::Row('ring_chat_log' => {
			'id' => $data->{'chat_id'},
		});
		unless ($rtrec->{'id'})
		{
			die(qq|Invalid chat log record id: $data->{'chat_id'}|);
		}
		if ($data->{'code'} == 200)
		{
			$rtrec->update({
				'delivered' => 1,
				'delivered_status' => 'sip:'. $data->{'code'},
				'ts_delivered' => strftime("%F %T", gmtime()),
			});
			my $uuid = $rtrec->data('uuid');
			my $fromuser = $rtrec->data('from_user_id');
			my $urec = new Note::Row('ring_user' => $fromuser, {'select' => ['login']});
			my $ext = $urec->data('login');
			$ext =~ s/\@/%40/;
			my $router = new Ring::Route();
			my $siphost = $router->get_sip_host($ext);
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
		else # attempt to push chat
		{
			my $fromuser = $rtrec->data('from_user_id');
			my $urec = new Note::Row('ring_user' => $fromuser, {'select' => ['login']});
			my $ext = $urec->data('login');
			my $router = new Ring::Route();
			my $cinfo = $router->get_contact_info(
				'user_id' => $rtrec->data('to_user_id'),
				'email' => $ext,
			);
			if (defined $cinfo)
			{
				$ext = $cinfo->{'name'};
			}
			$rtrec->update({
				'delivered_status' => 'sip:'. $data->{'code'},
			});
			my $pushres = Ring::API->cmd(
				'path' => ['route', 'push', 'chat'],
				'data' => {
					'user_id' => $rtrec->data('to_user_id'),
					'from' => $ext,
					'body' => ($rtrec->data('message_type') eq 'image') ? 'Image' : $rtrec->data('message_body'),
				},
			);
			return $pushres;
		}
		return {
			'ok' => 1,
		};
	}
	elsif ($type eq 'command_result')
	{
		if ($data->{'command'}->{'chat_delivered'})
		{
			my $uuid = $data->{'command'}->{'chat_delivered'};
			my $rtrec = new Note::Row(
				'ring_chat_log' => {
					'uuid' => $uuid,
				},
			);
			if ($rtrec->id())
			{
				if ($data->{'code'} == 200)
				{
					$rtrec->update({
						'confirmed' => 1,
						'confirmed_status' => 'sip:'. $data->{'code'},
						'ts_confirmed' => strftime("%F %T", gmtime()),
					});
				}
				else
				{
					$rtrec->update({
						'confirmed_status' => 'sip:'. $data->{'code'},
					});
				}
			}
		}
		return {
			'ok' => 1,
		};
	}
}

# route chat
sub chat
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $host = $data->{'hostname'};
	my $from = $data->{'from'};
	my $to = $data->{'to'};
	my $uuid = $data->{'uuid'};
	my $router = new Ring::Route();
	# check from user
	my $fromuser = new Note::Row(
		'ring_user' => {'login' => $from},
	);
	unless ($fromuser->id())
	{
		return; # discard
	}
	my $target = $router->get_target_type(
		'target' => $to,
	);
	my $trow;
	if ($target eq 'email')
	{
		$trow = $router->get_target(
			'target' => 'email',
			'target_email' => $to,
		);
	}
	elsif ($target eq 'did')
	{
		$trow = $router->get_target(
			'target' => 'did',
			'target_did' => $to,
		);
	}
	unless (defined($trow) && $trow->{'id'})
	{
		return; # discard
	}
	my $touser = $trow->row('user_id', 'ring_user');
	# build message
	my $uid = $touser->id();
	#my $ext = "u_$uid";
	my $urec = new Note::Row('ring_user' => $uid, {'select' => ['login']});
	my $ext = $urec->data('login');
	$ext =~ s/\@/%40/;
	my $siphost = $router->get_sip_host($ext);
	my $qhost = $router->get_queue_host($host);
	my $req = {
		'to' => $ext,
		'from' => $from,
		'proxy' => $siphost,
		'queuehost' => $qhost,
	};
	my %msg = (
		'uuid' => $uuid,
	);
	if (defined $data->{'url'})
	{
		$req->{'url'} = $data->{'url'};
		$msg{'type'} = 'image';
		$msg{'media_url'} = $data->{'url'};
	}
	else
	{
		$req->{'body'} = $data->{'body'};
		$msg{'type'} = 'text';
		$msg{'message_body'} = $data->{'body'};
	}
	my $log = Ring::API->cmd(
		'path' => ['route', 'logger', 'chat'],
		'data' => {
			'from_user_id' => $fromuser->{'id'},
			'to_user_id' => $uid,
			'target_type' => $target,
			'target_id' => $trow->{'id'},
			%msg,
		},
	);
	unless ($log->{'ok'})
	{
		::_log($log);
	}
	$req->{'id'} = $log->{'chat_id'};
	$req->{'uuid'} = $uuid;
	$router->send_request('chat_out', $req);
	return {
		'ok' => 1,
	};
}

#sub push
#{
#	my ($obj, $param) = get_param(@_);
#	my $data = $param->{'data'};
#	my $path = $param->{'path'};
#	my $item = shift @$path;
#	if ($item eq 'call')
#	{
#		#::_log("Push Call API:", $data);
#		my $rc = new Note::Row('ring_user' => {'id' => $data->{'user_id'}});
#		if ($rc->id())
#		{
#			my $tokrc = new Note::Row('ring_user_push' => {
#				'user_id' => $rc->id(),
#				'push_type' => 'apple',
#			});
#			if ($tokrc->id())
#			{
#				my $tok = $tokrc->data('apns_token');
#				my $p = new Ring::Push();
#				my $ck = md5_hex($data->{'uuid'});
#				my $prq = Note::Row::create('ring_user_push_call' => {
#					'call_key' => $ck,
#					'call_uuid' => $data->{'uuid'},
#					'call_user_id' => $data->{'user_id'},
#					'call_host' => $data->{'hostname'},
#				});
#				$data->{'reply'}->(1);
#				$p->apns_push({
#					'body' => 'Incoming call from '. $data->{'caller_id'},
#					'data' => {
#						'call-id' => $ck,
#					},
#					'token' => $tok,
#					'sound' => 'ring.caf',
#					'loc-key' => 'IC_MSG',
#					'production' => $tokrc->data('production'),
#				});
#				return {
#					'ok' => 1,
#				};
#			}
#		}
#		$data->{'reply'}->(0);
#		return {
#			'ok' => 0,
#		};
#	}	
#	elsif ($item eq 'chat')
#	{
#		#::_log("Push Call API:", $data);
#		my $rc = new Note::Row('ring_user' => {'id' => $data->{'user_id'}});
#		if ($rc->id())
#		{
#			my $tokrc = new Note::Row('ring_user_push' => {
#				'user_id' => $rc->id(),
#				'push_type' => 'apple',
#			});
#			if ($tokrc->id())
#			{
#				my $tok = $tokrc->data('apns_token');
#				my $p = new Ring::Push();
#				$p->apns_push({
#					'body' => $data->{'from'}. ': '. substr($data->{'body'}, 0, 100),
#					'token' => $tok,
#					'sound' => 'msg.caf',
#					'loc-key' => 'IM_MSG',
#					'production' => $tokrc->data('production'),
#				});
#				return {
#					'ok' => 1,
#				};
#			}
#		}
#		return {
#			'ok' => 0,
#		};
#	}
#}

1;

