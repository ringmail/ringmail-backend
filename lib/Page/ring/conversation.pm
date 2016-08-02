package Page::ring::conversation;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';
use Data::GUID;

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::User;
use Ring::Route;
use Ring::Item;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log('conversation request', $form);
	my $uuid = $form->{'conv'};
	my $from = $form->{'from'};
	$from =~ s/\%40/\@/;
	my $user = new Note::Row(
		'ring_user' => {
			'login' => $from,
		},
	);
	my $res = ['error', 'identity'];
	if ($user->id())
	{
		my $uid = $user->id();
		my $to = $form->{'to'};
		$to =~ s/\%40/\@/;
		my $dest = lc($to);
		my $rt = new Ring::Route();
		my $type = $rt->get_target_type(
			'target' => $dest,
		);
		if (defined($type) && ($type eq 'email' || $type eq 'did'))
		{
			my $to_user = undef;
			my $target = undef;
			if ($type eq 'email')
			{
				$target = $rt->get_target(
					'type' => 'email',
					'email' => $dest,
				);
				if (defined $target)
				{
					$to_user = $target->data('user_id');
					$target = $target->id();
				}
				else
				{
					# error
					$res = ['error', 'notfound'];
				}
			}
			elsif ($type eq 'did')
			{
				$target = $rt->get_target(
					'type' => 'did',
					'did' => $dest,
				);
				if (defined $target)
				{
					$to_user = $target->data('user_id');
					$target = $target->id();
				}
				else
				{
					# error
					$res = ['error', 'notfound'];
				}
			}
			if (defined($to_user))
			{
				$res = $obj->setup_conv(
					'from_user_id' => $uid,
					'from_conversation_uuid' => $uuid,
					'to_user_id' => $to_user,
					'to_user_target_id' => $target,
				);
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log("Res:", $res);
	return encode_json($res);
}

sub setup_conv
{
	my ($obj, $param) = get_param(@_);
	my $uid = $param->{'from_user_id'};
	my $fromuuid = lc($param->{'from_conversation_uuid'});
	my $to = $param->{'to_user_id'};
	my $target = $param->{'to_user_target_id'};
	my @result = ('error', 'conversation');
	my $userto = new Note::Row(
		'ring_user' => {'id' => $to},
		'select' => ['login'],
	);
	my $dest = $userto->data('login');
	$dest =~ s/\@/%40/;
	my $rc = new Note::Row(
		'ring_conversation' => {
			'from_user_id' => $uid,
			'to_user_id' => $to,
		},
		'select' => [
			'to_user_target_id',
			'conversation_uuid',
		],
	);
	if ($rc->id())
	{
		if ($rc->data('to_user_target_id') != $target)
		{
			$rc->update({'to_user_target_id' => $target});
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
				'from_user_id' => $to,
				'to_user_id' => $uid,
			},
			'select' => [
				'to_user_target_id',
				'conversation_uuid',
			],
		);
		if ($replyrc->id())
		{
			my $rt = $replyrc->row('to_user_target_id', 'ring_target');
			my $newfrom;
			if ($rt->data('target_type') eq 'email')
			{
				$newfrom = $rt->row('email_id', 'ring_email')->data('email');
				$newfrom =~ s/\@/%40/;
			}
			elsif ($rt->data('target_type') eq 'did')
			{
				my $drec = $rt->row('did_id', 'ring_did')->data('did_code', 'did_number');
				$newfrom = '+'. $drec->{'did_code'}. $drec->{'did_number'};
			}
			@result = ('ok', $dest, $newfrom, $replyrc->data('conversation_uuid'));
		}
	}
	else
	{
		# setup request conversation
		my $send = $obj->get_conversation(
			'from_user_id' => $uid,
			'from_uuid' => $fromuuid,
			'to_user_id' => $to,
			'to_user_target_id' => $target,
		);
		# setup reply conversation
		my $rt = new Note::Row('ring_target' => {'id' => $target});
		my $replytarget = 'error';
		my $replytarget_id = 'error';
		if ($rt->data('target_type') eq 'email')
		{
			my $rprec = new Note::Row('ring_user_email' => {
				'user_id' => $uid,
				'primary_email' => 1,
			});
			if ($rprec->id())
			{
				$replytarget = $rprec->row('email_id', 'ring_email')->data('email');
				$replytarget =~ s/\@/%40/;
				my $trec = new Note::Row('ring_target' => {
					'user_id' => $uid,
					'email_id' => $rprec->data('email_id'),
				});
				$replytarget_id = $trec->id();
			}
		}
		elsif ($rt->data('target_type') eq 'did')
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
			'from_user_id' => $to,
			'to_user_id' => $uid,
			'to_user_target_id' => $replytarget_id,
		);
		@result = ('ok', $dest, $replytarget, $reply->{'uuid'});
	}
	return \@result;
}

sub get_conversation
{
	my ($obj, $param) = get_param(@_);
	my $from = $param->{'from_user_id'};
	my $uuid = $param->{'from_uuid'};
	my $to = $param->{'to_user_id'};
	my $target = $param->{'to_user_target_id'};
	my $rc = new Note::Row(
		'ring_conversation' => {
			'from_user_id' => $from,
			'conversation_uuid' => $uuid,
			'to_user_id' => $to,
			'to_user_target_id' => $target,
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
				'from_user_id' => $from,
				'to_user_id' => $to,
				'to_user_target_id' => $target,
			},
		);
		return {
			'uuid' => $uuid,
			'code' => $conv,
		};
	}
}

1;

