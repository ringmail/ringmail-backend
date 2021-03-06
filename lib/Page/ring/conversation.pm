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
	#::log('conversation request', $form);
	my $uuid = $form->{'conv'};
	my $from = $form->{'from'};
	$from =~ s/\%40/\@/;
	my $replyto = $form->{'reply'};
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
		$to =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		my $dest = lc($to);
		my $rt = new Ring::Route();
		my $type = $rt->get_target_type(
			'target' => $dest,
		);
		if (defined($type))
		{
			my $to_user = undef;
			my $target = undef;
			$target = $rt->get_target(
				'type' => $type,
				$type => $dest,
			);
			if (defined($target) && defined($target->id()))
			{
				my $replyok = 1;
				if (defined($replyto) && length($replyto))
				{
					my $replytype = $rt->get_target_type(
						'target' => $replyto,
					);
					my $replytarget = undef;
					if ($replytype eq 'domain' || $replytype eq 'hashtag')
					{
						$replytarget = $rt->get_target(
							'type' => $replytype,
							$replytype => $replyto,
						);
					}
					if (defined($replytarget) && defined($replytarget->id()))
					{
						unless ($replytarget->data('user_id') == $uid) # match reply-to to owner
						{
							$res = ['error', 'replyto'];
							$replyok = 0;
						}
					}
					else
					{
						$res = ['error', 'replyto'];
						$replyok = 0;
					}
				}
				else
				{
					$replyto = undef;
				}
				if ($replyok)
				{
					$target->data('user_id', 'target_type', 'hashtag_id', 'domain_id');
					$res = $rt->setup_conversation(
						'from_user_id' => $uid,
						'from_conversation_uuid' => $uuid,
						'to_user_target' => $target,
						'to_original' => $dest,
						'reply_to' => $replyto,
					);
				}
			}
			else
			{
				# error
				$res = ['error', 'notfound'];
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log("conversation response", $res);
	return encode_json($res);
}

1;

