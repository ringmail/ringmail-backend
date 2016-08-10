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
use Ring::Conversation;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log('conversation request', $form);
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
				my $conv = new Ring::Conversation();
				$res = $conv->setup_conv(
					'from_user_id' => $uid,
					'from_conversation_uuid' => $uuid,
					'to_user_id' => $to_user,
					'to_user_target_id' => $target,
				);
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	#::log("Res:", $res);
	return encode_json($res);
}

1;

