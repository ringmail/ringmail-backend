package Page::ring::app::register_user;
use strict;
use warnings;

use vars qw();

use Moose;
use Try::Tiny;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::Register;
use Ring::User;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log("Create User", {%$form, 'password' => ''});
	my $input = {
		'email' => $form->{'email'},
		'phone' => $form->{'phone'},
		'first_name' => $form->{'first_name'},
		'last_name' => $form->{'last_name'},
		'password' => $form->{'password'},
		#'contacts' => $form->{'contacts'},
	};
	my $reg = new Ring::Register();
	my $ok = 0;
	my $error;
	# validate input and check for duplicates
	try {
		$reg->validate_input($input);
		$reg->check_duplicate($input);
		$reg->create_user($input);
	} catch {
		if (blessed($_))
		{
			$error = $_->message();
		}
		else
		{
			::errorlog('Internal Error: '. $_);
			$error = 'Internal Error';
		}
	} finally {
		unless (@_)
		{
			$ok = 1;
		}
	};
	my $res;
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
			'error' => $error,
		};
	}
	$obj->{'response'}->content_type('application/json');
	::log("Result", $res);
	return encode_json($res);
}

1;

