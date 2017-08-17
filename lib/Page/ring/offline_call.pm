package Page::ring::offline_call;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64', 'decode_base64';

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
	#::log($form);
# TODO: enable access token
#	my $token = $form->{'access_token'};
#	if ($token eq $::app_config->{'token_offline_message'})
#	{
		my $phone = decode_base64($form->{'phone'});
		$phone =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		my $to = decode_base64($form->{'to'});
		$to =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		my $from = decode_base64($form->{'from'});
		$from =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		$from =~ s/\\/@/;
		#::log("From: $from To: $to");
		my $tophone = new Note::Row('ring_phone' => {'login' => $to});
		my $fromphone = new Note::Row('ring_phone' => {'login' => $phone});
		if ($tophone->id() && $fromphone->id())
		{
			my $urec = $tophone->row('user_id', 'ring_user');
			my $login = $urec->data('login');
			::log("Push Call From: $from ($phone) -> To: $login ($to) SIP:$form->{'call'}");
			my $push = new Ring::Push();
			$push->push_call(
				'from' => $from,
				'to_user_id' => $urec->id(),
				'call_id' => $form->{'call'},
			);
		}
#	}
	my $res = '';
	return $res;
}

1;

