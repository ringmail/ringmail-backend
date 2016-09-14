package Ring::Conversation;

use Moose;
use Data::Dumper;

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::Item;

no warnings qw(uninitialized);

sub setup_conv
{
	my ($obj, $param) = get_param(@_);
	my $uid = $param->{'from_user_id'};
	my $fromuuid = lc($param->{'from_conversation_uuid'});
	my $fromid = $obj->get_identity(
		'type' => 'user',
		'user_id' => $uid,
	);
	my $to = $param->{'to_user_id'};
	my $target = $param->{'to_user_target_id'};
	my @result = ('error', 'conversation');
	my $userto = new Note::Row(
		'ring_user' => {'id' => $to},
		'select' => ['login'],
	);
	my $dest = $userto->data('login');
	unless (defined($param->{'media'}) && $param->{'media'} eq 'call')
	{
		$dest =~ s/\@/%40/;
	}
	my $contact = $obj->get_contact(
		'from_user_id' => $uid,
		'to_user_id' => $to,
	);
	$contact = '' unless (defined $contact);
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
				unless (defined($param->{'media'}) && $param->{'media'} eq 'call')
				{
					$newfrom =~ s/\@/%40/;
				}
			}
			elsif ($rt->data('target_type') eq 'did')
			{
				my $drec = $rt->row('did_id', 'ring_did')->data('did_code', 'did_number');
				$newfrom = '+'. $drec->{'did_code'}. $drec->{'did_number'};
			}
			@result = ('ok', $dest, $newfrom, $replyrc->data('conversation_uuid'), $contact);
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
		@result = ('ok', $dest, $replytarget, $reply->{'uuid'}, $contact);
	}
	return \@result;
}

sub get_identity
{
	my ($obj, $param) = get_param(@_);
	
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

