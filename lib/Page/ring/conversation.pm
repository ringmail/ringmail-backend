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
	my $login = $form->{'login'};
	$login =~ s/\%40/\@/;
	my $user = new Note::Row(
		'ring_user' => {
			'login' => $login,
		},
	);
	my $res = ['error', 'error'];
	if ($user)
	{
		my $uid = $user->id();
		my $dest = lc($form->{'to'});
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
					$res = ['notfound', 'notfound'];
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
					$res = ['notfound', 'notfound'];
				}
			}
			if (defined($to_user))
			{
				my $codes = $obj->setup_conv(
					'from_user_id' => $uid,
					'to_user_id' => $to_user,
					'to_user_target_id' => $target,
				);
				$res = $codes;
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
	my $to = $param->{'to_user_id'};
	my $target = $param->{'to_user_target_id'};
	my ($code, $reply) = ('error', 'error');
	my $rt = new Ring::Route();
    my $rc = new Note::Row(
        'ring_conversation' => {
            'from_user_id' => $uid,
            'to_user_id' => $to,
        },
    );
	if ($rc->id())
	{
		$code = $rc->data('conversation_code');
		my $replyrc = new Note::Row(
			'ring_conversation' => {
				'from_user_id' => $to,
				'to_user_id' => $uid,
			},
		);
		if ($replyrc->id())
		{
			my $cur = $replyrc->data('to_user_target_id');
			unless (defined($cur) && $cur == $target)
			{
				$replyrc->update({
					'to_user_target_id' => $target,
				});
			}
			$reply = $replyrc->data('conversation_code');
		}
	}
	else
	{
		# setup request conversation
		$code = $rt->get_conversation(
			'from_user_id' => $uid,
			'to_user_id' => $to,
			'to_user_target_id' => undef,
		);
		# setup reply conversation
		$reply = $rt->get_conversation(
			'from_user_id' => $to,
			'to_user_id' => $uid,
			'to_user_target_id' => $target,
		);
	}
	return [$code, $reply];
}

1;

