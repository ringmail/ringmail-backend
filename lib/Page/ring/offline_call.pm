package Page::ring::offline_call;
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
use Note::Param;

use Ring::Route;
use Ring::Push;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log($form);
# TODO: enable access token
#	my $token = $form->{'access_token'};
#	if ($token eq $::app_config->{'token_offline_message'})
#	{
		my $from = $form->{'from'};
		my $fromphone = new Note::Row(
			'ring_phone' => {
				'login' => $from,
			},
		);
		if ($fromphone->id())
		{
			my $fromlogin = $fromphone->row('user_id', 'ring_user')->data('login');
			my $to = $form->{'to'};
			$to =~ s/\\/@/;
			::log("From: $from ($fromlogin) To: $to");
			my $urec = new Note::Row(
				'ring_user' => {
					'login' => $to,
				},
			);
			if ($urec->id())
			{
				my $push = new Ring::Push();
				$push->push_call(
					'from' => $fromlogin,
					'to' => $to,
				);
			}
		}
#	}
	my $res = '';
	return $res;
}

1;

