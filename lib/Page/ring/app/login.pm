package Page::ring::app::login;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS qw( encode_json decode_json );
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';
use LWP::UserAgent;

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::User;
use Ring::User::Contacts;
use Ring::Google_OAuth2;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log('Login', {%$form, 'password' => ''});
	my $res;
	my $user;
	my $newpass = '';
	if (exists $form->{'idToken'})
	{
		my $ua = new Ring::Google_OAuth2();
		my $response = $ua->get_token_info(
			'token' => $form->{'idToken'},
		);
		if (defined $response)
		{
			if (($response->{'email'} eq $form->{'login'}) && ($response->{'email_verified'} eq 'true'))
			{
				my $urc = new Note::Row(
					'ring_user' => {'login' => $form->{'login'}},
				);
				if ($urc->id())
				{
					open (S, '-|', '/home/note/app/ringmail/scripts/genrandstring.pl');
					$/ = undef;
					$newpass = <S>;
					::log('New PW:'. $newpass);
					close(S);
					my $userChange = new Ring::User('id' => $urc->id());
					$userChange->password_change('password' => $newpass);
					$user = Ring::User::login(
						'login' => $form->{'login'},
						'password' => $newpass,
					);
				}
				else
				{
					$res = {
						'result' => 'error',
						'error' => 'register',
						'idToken' => $form->{'idToken'},
					};
					$obj->{'response'}->content_type('application/json');
					#::log($res);
					return encode_json($res);
				}
			}
		}
	}
	else
	{	
		$user = Ring::User::login(
			'login' => $form->{'login'},
			'password' => $form->{'password'},
		);
	}

	if ($user)
	{
		::log("Login: $form->{'login'} Version: $form->{'version'}-$form->{'build'}");
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
				'ringmail_password' => $newpass,
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
	::log($res);
	return encode_json($res);
}

1;

