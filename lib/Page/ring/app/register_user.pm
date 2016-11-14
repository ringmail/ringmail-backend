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
use Ring::API;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log("Create User", {%$form, 'password' => ''});
	my $reg = new Ring::Register();
	my $ok = 0;
	my $error;
	# validate input and check for duplicates
	try {
		$reg->validate_input($form);
		$reg->check_duplicate($form);
		$ok = 1;
	} catch {
		$error = $_;
	};
	if ($ok)
	{
		# create the user
		$reg->create_user($form);
	}
	else
	{
		$res = {
			'result' => 'error',
			'error' => $error->{'message'},
		};
	}
	my %error_detail = ();
	if (
		Email::Valid->address($form->{'email'}) &&
		$form->{'phone'} =~ /^\+?\d{6,7}[2-9]\d{3}$/
	) {
		my $ck = Ring::API->cmd(
			'path' => ['user', 'check', 'user'],
			'data' => {
				'email' => $form->{'email'},
				'phone' => $form->{'phone'},
			},
		);
		unless ($ck->{'ok'})
		{
			#::log($ck);
			$err = 'duplicate';
			$error_detail{'duplicate'} = $ck->{'duplicate'};
		}
	}
	unless ($err)
	{
		my $mkuser = Ring::API->cmd(
			'path' => ['user', 'create'],
			'data' => {
				'email' => $form->{'email'},
				'phone' => $form->{'phone'},
				'password' => $form->{'password'},
				'first_name' => $form->{'first_name'},
				'last_name' => $form->{'last_name'},
			},
		);
		if ($mkuser->{'ok'})
		{
			$res = {
				'result' => 'ok',
			};
		}
		else
		{
			$err = 'internal';
			#::_log("Create User Error", $mkuser->{'errors'}->[2]->{'error'});
			::_log("Create User Error", $mkuser);
		}
	}
	if ($err)
	{
		$res = {
			'result' => 'error',
			'error' => $err,
			%error_detail,
		};
	}
	$obj->{'response'}->content_type('application/json');
	::log("Result", $res);
	return encode_json($res);
}

1;

