package Page::ring::app::resend_verify;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';
use Number::Phone::Country;

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::User;
use Ring::API;
use Ring::Item;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log($form);
	$form->{'email'} =~ s/^\s+//g;
	$form->{'email'} =~ s/\s+$//g;
	my $res;
	my $err = 'other';
	if (defined $form->{'email'} && Email::Valid->address($form->{'email'}))
	{
		$err = 'email';
		my $ck = Ring::API->cmd(
			'path' => ['user', 'check', 'user'],
			'data' => {
				'email' => $form->{'email'},
			},
		);
		if (! $ck->{'ok'}) # user is a dup
		{
			my $uid = sqltable('ring_user')->get(
				'result' => 1,
				'select' => 'id',
				'where' => {'login' => $form->{'email'}},
			);
			my $user = new Ring::User($uid);
			if ($user->row()->data('verified') == 0)
			{
				$user->verify_email_send(
					'email' => $form->{'email'},
				);
				$err = '';
				$res = {
					'result' => 'ok',
				};
			}
			else
			{
				$err = 'verified';
			}
		}
	}
	elsif (defined($form->{'phone'}) && $form->{'phone'} =~ /^\+?\d{10,16}$/)
	{
		my $phone = $form->{'phone'};
		#::log("Phone: $phone");
		my ($iso_country_code, $did_code) = Number::Phone::Country::phone2country_and_idd($phone);
		my $did_number = $phone;
		my $ms = "\\+". $did_code;
		my $dm = qr($ms);
		$did_number =~ s/^$dm//;
		#::log("Code: $did_code Number: $did_number");
		$err = 'phone';
		my $item = new Ring::Item();
		my $phitem = $item->item(
			'type' => 'did',
			'did_code' => $did_code,
			'did_number' => $did_number,
			'no_create' => 1,
		);
		if (defined $phitem) # make sure DID exists in database at all
		{
			my $rc = new Note::Row(
				'ring_user_did' => {
					'did_id' => $phitem->id(),
				},
			);
			if ($rc->id())
			{
				::log("Found User DID: ". $rc->id());
				if (! $rc->data('verified'))
				{
					my $out = Ring::API->cmd(
						'path' => ['user', 'target', 'verify', 'did', 'generate'],
						'data' => {
							'user_id' => $rc->data('user_id'),
							'phone' => $phone,
							'send_sms' => 1,
						},
					);
					if ($out->{'ok'})
					{
						$err = '';
						$res = {'result' => 'ok'};
					}
				}
				else
				{
					$err = 'verified';
				}
			}
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
	#::log("Result", $res);
	return encode_json($res);
}

1;

