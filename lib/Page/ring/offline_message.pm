package Page::ring::offline_message;
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
	my $token = $form->{'access_token'};
	if ($token eq $::app_config->{'token_offline_message'})
	{
		my $from = $form->{'from'};
		my $to = $form->{'to'};
		$from =~ s/ /+/g; # Fix URL encoding issues (there are never spaces in RingMail addresses)
		$to =~ s/ /+/g;
		my $body = $form->{'body'};
		::log("From: $from To: $to Body: $body");
		my $push = new Ring::Push();
		$push->push_message(
			'from' => $from,
			'to' => $to,
			'body' => $body,
		);
	}
	my $res = '';
	return $res;
}

1;

