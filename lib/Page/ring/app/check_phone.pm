package Page::ring::app::check_phone;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';
use Try::Tiny;
use Scalar::Util 'blessed';

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
	::log('Input:', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $err = undef;
	my $res;
	if ($user)
	{
		my $ok = 0;
		try {
			$ok = $user->verify_phone(
				'phone' => $form->{'phone'},
				'verify_code' => $form->{'code'},
			);
		} catch {
			if (blessed($_))
			{
				if ($_->message() =~ /already verified/i)
				{
					$ok = 1;
				}
				else
				{
					$err = undef;
				}
			}
			else
			{
 				::errorlog("Internal Error: $_");
				$err = 'Internal error';
			}
		};
		if ($ok)
		{
			$res = {
				'result' => 'ok',
			};
		}
		else
		{
			$res = {
				'result' => 'error',
				'error' => $err,
			};
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log('Result:', $res);
	return encode_json($res);
}

1;

