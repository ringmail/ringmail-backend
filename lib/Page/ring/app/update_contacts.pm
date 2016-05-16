package Page::ring::app::update_contacts;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json', 'decode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::User;
use Ring::User::Contacts;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log({%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {};
	if ($user)
	{
		my $ctdata = decode_json($form->{'contacts'});
		my $item = new Ring::Item();
		my $devid = $item->item(
			'type' => 'device',
			'device_uuid' => $form->{'device'},
			'user_id' => $user->id(),
		)->id();
		# TODO: validate form data
		my $cobj = new Ring::User::Contacts(
			'user_id' => $user->id(),
		);
		$cobj->load_contacts(
			'device_id' => $devid,
			'contacts' => $ctdata,
			'purge' => 1,
		);
		my $rgusers = $cobj->get_matched_contacts(
			'device_id' => $devid,
		);
		my $rgmatches = $cobj->get_device_matches(
			'device_id' => $devid,
		);
		$res = {
			'rg_contacts' => $rgusers,
			'rg_matches' => $rgmatches,
			'result' => 'ok',
		};
	}
	$obj->{'response'}->content_type('application/json');
	#::log($res);
	return encode_json($res);
}

1;

