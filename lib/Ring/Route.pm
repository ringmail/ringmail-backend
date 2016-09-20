package Ring::Route;
use strict;
use warnings;

use vars qw(%usercheck);

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Email::Valid;
use Authen::Passphrase;
use Authen::Passphrase::SaltedSHA512;
use POSIX 'strftime';
use String::Random;
use MIME::Lite;
#use Net::RabbitMQ;
use JSON::XS 'encode_json';
use Digest::MD5 'md5_base64';
use Data::GUID;

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::Item;

no warnings qw(uninitialized);

sub get_target_user_id
{
	my ($obj, $param) = get_param(@_);
	my $dest = $param->{'target'};
	my $type = $obj->get_target_type('target' => $dest);
	my $trow = $obj->get_target(
		'type' => $type,
		$type => $dest,
	);
	if (defined($trow) && $trow->id())
	{
		return $trow->data('user_id');
	}
}

sub get_phone_user
{
	my ($obj, $param) = get_param(@_);
	my $phone = $param->{'phone_login'};
	my $ph = new Note::Row('ring_phone' => {'login' => $phone});
	if ($ph->id())
	{
		return {
			'user_id' => $ph->data('user_id'),
			'login' => $ph->row('user_id', 'ring_user')->data('login'),
		};
	}
	return undef;
}

sub get_target_type
{
	my ($obj, $param) = get_param(@_);
	my $dest = $param->{'target'};
	my $target = undef;
	if ($dest =~ /^\#[a-z0-9\_]{1,160}$/)
	{
		$target = 'hashtag';
	}
	elsif ($dest =~ /\@/)
	{
		if (Email::Valid->address($dest))
		{
			$target = 'email';
		}
	}
	elsif ($dest =~ /^\+?\d+$/)
	{
		$target = 'did';
	}
	elsif ($dest =~ /\./ && $dest =~ /^[a-z0-9\.\-]+$/) # domain
	{
		$target = 'domain';
	}
	return $target;
}

sub get_route
{
	my ($obj, $param) = get_param(@_);
	#::_log('Get Route', $param);
	my $item = new Ring::Item();
	my $trow = $obj->get_target($param);
	#::log("Target:", $trow);
	my $res = undef;
	if (defined($trow) && $trow->{'id'})
	{
# detailed routing (V1)
		my $troute = new Note::Row('ring_target_route' => {
			'target_id' => $trow->id(),
			'seq' => 0,
		});
		#::log("Target Route:", $troute);
		if ($troute->id())
		{
			my $rtrow = $troute->row('route_id', 'ring_route');
			my $rtdata = $rtrow->data();
			if ($rtdata->{'route_type'} eq 'app')
			{
				my $tuid = $trow->data('user_id');
				my $tphone = new Note::Row('ring_phone' => {'user_id' => $tuid});
				if ($tphone->id())
				{
					$res = {
						'type' => 'phone',
						'route' => $tphone->data('login'),
					};
				}
			}
			elsif ($rtdata->{'route_type'} eq 'did')
			{
				my $didrec = $rtrow->row('did_id', 'ring_did');
				my $did = '+'. $didrec->data('did_code'). $didrec->data('did_number');
				$res = {
					'type' => 'did',
					'route' => $did,
				};
			}
			elsif ($rtdata->{'route_type'} eq 'sip')
			{
				my $siprec = $rtrow->row('sip_id', 'ring_sip');
				my $sip = $siprec->data('sip_url');
				$res = {
					'type' => 'sip',
					'route' => $sip,
				};
			}
		}
		else
		{
			my $tuid = $trow->data('user_id');
			my $tphone = new Note::Row('ring_phone' => {'user_id' => $tuid});
			if ($tphone->id())
			{
				$res = {
					'route' => 'phone',
					'phone' => $tphone->data('login'),
				};
			}
		}
		return $res;
	}
	return undef;
}

sub get_target
{
	my ($obj, $param) = get_param(@_);
	#::_log('Get Route', $param);
	my $item = new Ring::Item();
	my $tgt = $param->{'type'};
	my $trec = undef;
	if ($tgt eq 'email')
	{
		my $em = $param->{'email'};
		my $erec = $item->item(
			'type' => 'email',
			'email' => $em,
			'no_create' => 1,
		);
		return undef unless (defined $erec);
		my $trow = new Note::Row(
			'ring_target' => {
				'email_id' => $erec->id(),
			},
		);
		return $trow;
	}
	elsif ($tgt eq 'domain')
	{
		my $em = $param->{'domain'};
		my $erec = $item->item(
			'type' => 'domain',
			'domain' => $em,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'domain_id' => $erec->id(),
			},
		);
		return $trow;
	}
	elsif ($tgt eq 'did')
	{
		my $num = $param->{'did'};
		my $erec = $item->item(
			'type' => 'did',
			'did_number' => $num,
			'no_create' => 1,
		);
		return undef unless (defined $erec);
		my $trow = new Note::Row(
			'ring_target' => {
				'did_id' => $erec->id(),
			},
		);
		return $trow;
	}
	elsif ($tgt eq 'hashtag')
	{
		my $tag = $param->{'hashtag'};
		$tag =~ s/^#//;
		my $htrec = new Note::Row(
			'ring_hashtag' => {
				'hashtag' => $tag,
			},
		);
		return undef unless (defined $htrec->id());
		my $trow = new Note::Row(
			'ring_target' => {
				'hashtag_id' => $htrec->id(),
			},
		);
		return $trow;
	}
	return undef;
}

sub setup_conversation
{
	my ($obj, $param) = get_param(@_);
	my $uid = $param->{'from_user_id'};
	my $fromuuid = lc($param->{'from_conversation_uuid'});
	# TOOD: allow sending from other identities than the main user account
	my $from_identity_id = $obj->get_identity(
		'type' => 'user',
		'user_id' => $uid,
	);
	my $target = $param->{'to_user_target'};
	my $target_type = $target->data('target_type');
	my $to_user_id = $target->data('user_id');
	my $to_item_id;
	my $origto = $param->{'to_original'};
	my $replyto = $param->{'reply_to'};
	if ($target_type eq 'hashtag')
	{
		$to_item_id = $target->data('hashtag_id');
	}
	elsif ($target_type eq 'domain')
	{
		$to_item_id = $target->data('domain_id');
	}
	else
	{
		$origto = '';
	}
	my $to_identity_id = $obj->get_identity(
		'type' => ($target_type eq 'did' || $target_type eq 'email') ? 'user' : $target_type,
		'user_id' => $to_user_id,
		'item_id' => $to_item_id,
	);
	my @result = ('error', 'conversation');
	my $userto = new Note::Row(
		'ring_user' => {'id' => $to_user_id},
		'select' => ['login'],
	);
	my $dest = $userto->data('login');
	unless (defined($param->{'media'}) && $param->{'media'} eq 'call')
	{
		$dest =~ s/\@/%40/;
	}
# TODO: fix
#	my $contact = $obj->get_contact(
#		'from_user_id' => $uid,
#		'to_user_id' => $to,
#	);
#	$contact = '' unless (defined $contact);
	my $contact = '';
	my $rc = new Note::Row(
		'ring_conversation' => {
			'from_identity_id' => $from_identity_id,
			'to_identity_id' => $to_identity_id,
		},
		'select' => [
			'to_user_target_id',
			'conversation_uuid',
		],
	);
	if ($rc->id())
	{
		if ($rc->data('to_user_target_id') != $target->id())
		{
			$rc->update({'to_user_target_id' => $target->id()});
		}
		if (length($fromuuid)) # empty for delivery receipts
		{
			if ($rc->data('conversation_uuid') ne $fromuuid) # TODO: validate uuids
			{
				$rc->update({'conversation_uuid' => $fromuuid});
			}
		}
		my $replyrc = new Note::Row(
			'ring_conversation' => {
				'from_identity_id' => $to_identity_id,
				'to_identity_id' => $from_identity_id,
			},
			'select' => [
				'to_user_target_id',
				'conversation_uuid',
			],
		);
		if ($replyrc->id())
		{
			my $newfrom;
			if (defined $replyto)
			{
				$newfrom = $replyto;
			}
			else
			{
				my $rt = $replyrc->row('to_user_target_id', 'ring_target');
				my $replytype = $rt->data('target_type');
				if ($replytype eq 'email')
				{
					$newfrom = $rt->row('email_id', 'ring_email')->data('email');
				}
				elsif ($replytype eq 'did')
				{
					my $drec = $rt->row('did_id', 'ring_did')->data('did_code', 'did_number');
					$newfrom = '+'. $drec->{'did_code'}. $drec->{'did_number'};
				}
				elsif ($replytype eq 'domain')
				{
					$newfrom = $rt->row('domain_id', 'ring_domain')->data('domain');
				}
				elsif ($replytype eq 'hashtag')
				{
					$newfrom = '#'. $rt->row('hashtag_id', 'ring_hashtag')->data('hashtag');
				}
			}
			unless (defined($param->{'media'}) && $param->{'media'} eq 'call')
			{
				$newfrom =~ s/\@/%40/;
				$newfrom =~ s/\#/%23/;
			}
			@result = ('ok', $dest, $newfrom, $replyrc->data('conversation_uuid'), $contact, $origto);
		}
	}
	else
	{
		# setup request conversation
		my $send = $obj->get_conversation(
			'from_identity_id' => $from_identity_id,
			'from_uuid' => $fromuuid,
			'to_identity_id' => $to_identity_id,
			'to_user_target_id' => $target->id(),
		);
		# setup reply conversation
		my $replytarget = 'error';
		my $replytarget_id = 'error';
		if ($target_type eq 'email' || $target_type eq 'domain' || $target_type eq 'hashtag')
		{
			my $rprec = new Note::Row('ring_user_email' => {
				'user_id' => $uid,
				'primary_email' => 1,
			});
			if ($rprec->id())
			{
				$replytarget = $rprec->row('email_id', 'ring_email')->data('email');
				unless (defined($param->{'media'}) && $param->{'media'} eq 'call')
				{
					$replytarget =~ s/\@/%40/;
				}
				my $trec = new Note::Row('ring_target' => {
					'user_id' => $uid,
					'email_id' => $rprec->data('email_id'),
				});
				$replytarget_id = $trec->id();
			}
		}
		elsif ($target_type eq 'did')
		{
			my $rprec = new Note::Row('ring_user_did' => {
				'user_id' => $uid,
				'verified' => 1,
				# TODO: add primary_did field
			});
			if ($rprec->id())
			{
				my $drec = $rprec->row('did_id', 'ring_did')->data('did_code', 'did_number');
				$replytarget = '+'. $drec->{'did_code'}. $drec->{'did_number'};
				my $trec = new Note::Row('ring_target' => {
					'user_id' => $uid,
					'did_id' => $rprec->data('did_id'),
				});
				$replytarget_id = $trec->id();
			}
		}
		my $reply = $obj->get_conversation(
			'from_identity_id' => $to_identity_id,
			'to_identity_id' => $from_identity_id,
			'to_user_target_id' => $replytarget_id,
		);
		if (defined $replyto)
		{
			$replytarget = $replyto;
		}
		@result = ('ok', $dest, $replytarget, $reply->{'uuid'}, $contact, $origto);
	}
	return \@result;
}

sub get_identity
{
	my ($obj, $param) = get_param(@_);
	my $type = $param->{'type'};
	my $uid = $param->{'user_id'};
	my $item_id = $param->{'item_id'};
	my $rc;
	if ($type eq 'user')
	{
		$rc = Note::Row::find_insert('ring_conversation_identity' => {
			'identity_type' => $type,
			'user_id' => $uid,
			'domain_id' => undef,
			'hashtag_id' => undef,
		});
	}
	elsif ($type eq 'domain')
	{
		$rc = Note::Row::find_insert('ring_conversation_identity' => {
			'identity_type' => $type,
			'user_id' => $uid,
			'domain_id' => $item_id,
		});
	}
	elsif ($type eq 'hashtag')
	{
		$rc = Note::Row::find_insert('ring_conversation_identity' => {
			'identity_type' => $type,
			'user_id' => $uid,
			'hashtag_id' => $item_id,
		});
	}
	return $rc->id();
}

sub get_conversation
{
	my ($obj, $param) = get_param(@_);
	my $from = $param->{'from_identity_id'};
	my $uuid = $param->{'from_uuid'};
	my $to = $param->{'to_identity_id'};
	my $tid = $param->{'to_user_target_id'};
	my $rc = new Note::Row(
		'ring_conversation' => {
			'from_identity_id' => $from,
			'to_identity_id' => $to,
		},
	);
	if ($rc->id())
	{
		return $rc->data('conversation_code');
	}
	else
	{
		if ( (! defined($uuid)) || (! length($uuid)) )
		{
			# generate uuid
			my $g = new Data::GUID();
			$uuid = lc($g->as_string());
		}
		my $conv;
		my $sr = new String::Random();
		my $tbl = sqltable('ring_conversation');
		# create code
		do {
			$conv = $sr->randregex('[a-z0-9]{8}');
		} while ($tbl->count(
			'conversation_code' => $conv,
		));
		Note::Row::create(
			'ring_conversation' => {
				'conversation_code' => $conv,
				'conversation_uuid' => $uuid,
				'from_identity_id' => $from,
				'to_identity_id' => $to,
				'to_user_target_id' => $tid,
			},
		);
		return {
			'uuid' => $uuid,
			'code' => $conv,
		};
	}
}

sub get_contact
{
	my ($obj, $param) = get_param(@_);
	my $rq = sqltable('ring_contact')->get(
		'array' => 1,
		'result' => 1,
		'select' => ['t.internal_id'],
		'table' => 'ring_contact t',
		'where' => [
			{
				't.user_id' => $param->{'to_user_id'},
				't.matched_user_id' => $param->{'from_user_id'},
			},
			'and',
			'device_id = (SELECT d.id FROM ringmail.ring_device d WHERE d.user_id=t.user_id ORDER BY d.id DESC LIMIT 1)',
		],
	);
	return $rq;
}

1;

