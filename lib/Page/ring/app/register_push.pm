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
	#::log($form);
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
	if ($user)
	{
		my $tok = $form->{'token'};
		#::log("Token: $tok\n");
		if ($tok =~ /pn-type=(\w+);app-id=(.*?);pn-tok=(.*)$/)
		{
			my $type = $1;
			#::log($type);
			if ($type eq 'apple')
			{
				my $data = {
					'app' => $2,
					'token' => $3,
				};
				$user->row()->update({
					'push_apns_data' => encode_json($data),
				});
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

