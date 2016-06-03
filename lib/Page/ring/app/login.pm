package Page::ring::app::login;
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
use Ring::User::Contacts;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log({%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res;
	if ($user)
	{
		my $verified = $user->row()->data('verified');
		if ($verified)
		{
			my $chatpw = $user->row()->data('password_chat');
			my $sipauth = sqltable('ring_phone')->get(
				'select' => ['login', 'password'],
				'where' => {
					'user_id' => $user->id(),
				},
				'order' => 'id asc limit 1',
			);
			my $phone = sqltable('ring_user_did')->get(
				'array' => 1,
				'table' => 'ring_did d, ring_user_did ud',
				'select' => ['d.did_code', 'd.did_number'],
				'join' => 'd.id=ud.did_id',
				'where' => {
					'ud.user_id' => $user->{'id'},
				},
				'order' => 'ud.id asc',
				'limit' => 1,
			);
			if (scalar @$phone)
			{
				$phone = shift @$phone;
				$phone = '+'. $phone->[0]. $phone->[1];
			}
			else
			{
				$phone = '+'. '0' x 11;
			}
			$res = {
				'result' => 'ok',
				'sip_login' => $sipauth->[0]->{'login'},
				'sip_password' => $sipauth->[0]->{'password'},
				'chat_password' => $chatpw,
				'phone' => $phone,
				'contacts' => 0,
				'rg_contacts' => [],
				'ts_latest' => '',
			};
			my $cobj = new Ring::User::Contacts(
				'user_id' => $user->id(),
			);
			my $item = new Ring::Item();
			if (defined($form->{'device'}) && length($form->{'device'}))
			{
				my $devid = $item->item(
					'type' => 'device',
					'device_uuid' => $form->{'device'},
					'user_id' => $user->id(),
				)->id();
				my $syncts = $cobj->sync_timestamp(
					'device_id' => $devid,
				);
				$res->{'ts_latest'} = $syncts;
				my $ct = $cobj->get_contacts_count(
					'device_id' => $devid,
				);
				$res->{'contacts'} = $ct;
				my $rgusers = $cobj->get_matched_contacts(
					'device_id' => $devid,
				);
				$res->{'rg_contacts'} = $rgusers;
			}
		}
		else
		{
			$res = {
				'result' => 'error',
				'error' => 'verify',
			};
		}
	}
	else
	{
		$res = {
			'result' => 'error',
			'error' => 'credentials',
		};
	}
	$obj->{'response'}->content_type('application/json');
	#::log($res);
	return encode_json($res);
}

1;

