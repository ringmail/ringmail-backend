package Page::ring::app::conversation;
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
	::log('conversation request', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
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
					$res->{'error'} = 'notfound';
				}
			}
			elsif ($type eq 'did')
			{
				$target = $rt->get_target(
					'type' => 'did',
					'did' => $dest,
				);
				if (defined $target->id())
				{
					$to_user = $target->data('user_id');
					$target = $target->id();
				}
				else
				{
					# error
					$res->{'error'} = 'notfound';
				}
			}
			if (defined($to_user))
			{
				my $code = $obj->setup_conv(
					'from_user_id' => $uid,
					'to_user_id' => $to_user,
					'to_user_target_id' => $target,
				);
				$res = {
					'result' => 'ok',
					'code' => $code,
				};
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

sub setup_conv
{
	my ($obj, $param) = get_param(@_);
	my $uid = $param->{'from_user_id'};
	my $to = $param->{'to_user_id'};
	my $target = $param->{'to_user_target_id'};
	my $rt = new Ring::Route();
	# setup request conversation
	my $code = $rt->get_conversation(
		'from_user_id' => $uid,
		'to_user_id' => $to,
		'to_user_target_id' => $target,
	);
	# setup reply conversation
	$rt->get_conversation(
		'from_user_id' => $to,
		'to_user_id' => $uid,
		'to_user_target_id' => undef,
	);
	return $code;
}

1;

