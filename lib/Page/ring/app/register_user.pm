package Page::ring::app::register_user;
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
	my $err = '';
	if (Email::Valid->address($form->{'email'}))
	{
		my $ck = Ring::API->cmd(
			'path' => ['user', 'check', 'user'],
			'data' => {
				'email' => $form->{'email'},
			},
		);
		unless ($ck->{'ok'})
		{
			$err = 'duplicate';
		}
	}
	unless ($err)
	{
		my $mkuser = Ring::API->cmd(
			'path' => ['user', 'create'],
			'data' => {
				'email' => $form->{'email'},
				'password' => $form->{'password'},
				'password2' => $form->{'password'},
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
			::_log("Create User Error", $mkuser->{'errors'}->[2]->{'error'});
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
	::log("Create User", $form, "Result", $res);
	return encode_json($res);
}

1;

