package Page::ring::app::resend_verify;
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
use Ring::API;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log($form);
	$form->{'email'} =~ s/^\s+//g;
	$form->{'email'} =~ s/\s+$//g;
	my $res;
	my $err = 'email';
	if (Email::Valid->address($form->{'email'}))
	{
		my $ck = Ring::API->cmd(
			'path' => ['user', 'check', 'user'],
			'data' => {
				'email' => $form->{'email'},
			},
		);
		if (! $ck->{'ok'}) # user is a dup
		{
			my $uid = sqltable('ring_user')->get(
				'result' => 1,
				'select' => 'id',
				'where' => {'login' => $form->{'email'}},
			);
			my $user = new Ring::User($uid);
			if ($user->row()->data('verified') == 0)
			{
				$user->verify_email_send(
					'email' => $form->{'email'},
				);
				$err = '';
				$res = {
					'result' => 'ok',
				};
			}
			else
			{
				$res = {
					'result' => 'error',
					'error' => 'verified',
				};
			}
		}
	}
	if ($err)
	{
		$res = {
			'result' => 'error',
			'error' => $err,
		};
	}
	$obj->{'response'}->content_type('application/json');
	return encode_json($res);
}

1;

