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
	::log("Create User", {%$form, 'password' => ''});
	$form->{'email'} =~ s/^\s+//g;
	$form->{'email'} =~ s/\s+$//g;
	my $ht = $form->{'hashtag'};
	$ht =~ s/^\s+//g;
	$ht =~ s/^\#//;
	$ht =~ s/\s+$//g;
	$ht = lc($ht);
	my $res;
	my $err = '';
	my %error_detail = ();
	if (
		Email::Valid->address($form->{'email'}) &&
		$form->{'phone'} =~ /^\+?\d{6,7}[2-9]\d{3}$/ &&
		$ht =~ /^[a-z0-9_]{0,160}$/
	) {
		my $ck = Ring::API->cmd(
			'path' => ['user', 'check', 'user'],
			'data' => {
				'email' => $form->{'email'},
				'phone' => $form->{'phone'},
				'hashtag' => $ht,
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
				'hashtag' => $ht,
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

