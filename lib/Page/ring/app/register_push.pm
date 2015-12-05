package Page::ring::app::register_push;
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

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log($form);
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
	if ($user)
	{
		#::log("Token: $tok\n");
		if ($form->{'token'} =~ /pn-type=(\w+);app-id=(.*?);pn-tok=(.*)$/)
		{
			my $type = $1;
			my $app = $2;
			my $tok = $3;
			#::log($type);
			if ($type eq 'apple')
			{
				my $rc = new Note::Row(
					'ring_user_apns' => {
						'user_id' => $user->{'id'},
					},
				);
				if ($rc->id())
				{
					$rc->update({
						'push_app' => $app,
						'main_token' => $tok,
					});
				}
				else
				{
					Note::Row::create(
						'ring_user_apns' => {
							'user_id' => $user->{'id'},
							'push_app' => $app,
							'main_token' => $tok,
						},
					);
				}
				$res = {
					'result' => 'ok',
				};
			}
		}
		if ($form->{'voip_token'} =~ /pn-type=(\w+);app-id=(.*?);pn-tok=(.*)$/)
		{
			my $type = $1;
			my $app = $2;
			my $tok = $3;
			if ($type eq 'apple')
			{
				my $rc = new Note::Row(
					'ring_user_apns' => {
						'user_id' => $user->{'id'},
					},
				);
				if ($rc->id())
				{
					$rc->update({
						'voip_token' => $tok,
					});
				}
				else
				{
					Note::Row::create(
						'ring_user_apns' => {
							'user_id' => $user->{'id'},
							'voip_token' => $tok,
						},
					);
				}
				$res = {
					'result' => 'ok',
				};
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	#::log($res);
	return encode_json($res);
}

1;

