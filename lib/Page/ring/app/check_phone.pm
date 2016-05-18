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

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::API;
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
	my $res = {
		'result' => 'error',
	};
	if ($user)
	{
		my $item = new Ring::Item();
		my $phitem = $item->item(
			'type' => 'did',
			'did_number' => $form->{'phone'},
			'no_create' => 1,
		);
		if (defined $phitem) # make sure DID exists in database at all
		{
			$form->{'code'} =~ s/\D//mg;
			if (length($form->{'code'}) == 4)
			{
				my $ck = Ring::API->cmd(
					'path' => ['user', 'target', 'verify', 'did', 'check'],
					'data' => {
						'user_id' => $user->{'id'},
						'did_id' => $phitem->{'id'},
						'verify_code' => $form->{'code'},
					},
				);
				if ($ck->{'ok'} || $ck->{'error'} =~ /already verified/i)
				{
					$res = {'result' => 'ok'};
				}
				else
				{
					::log('Input:', {%$form, 'password' => ''});
					::log("Check Failed", $ck);
				}
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log('Result:', $res);
	return encode_json($res);
}

1;

