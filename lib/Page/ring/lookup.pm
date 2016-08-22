package Page::ring::lookup;
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
use Ring::Conversation;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log($form);
	my $res = 'noentry';
	my $route = new Ring::Route();
	my $from = decode_base64($form->{'from'});
	my $to = decode_base64($form->{'to'});
	$from =~ s/^sip\://;
	$from =~ s/\@.*//g;
	my $fru = $route->get_phone_user(
		'phone_login' => $from,
	);
	#::log($fru);
#	if (defined $fru)
#	{
#		$from = $fru->{'login'};
#		$from =~ s/\@/\\/;
#		$from = uri_escape($from); # TODO: expand?
#	}
	$to =~ s/^sip\://;
	$to =~ s/\@.*//g;
	$to =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	#::log("From: $from To: $to");
	my $target = {};
	if ($to =~ /(\\|%)/ || $to =~ /^\+?\d+$/)
	{
		$to =~ s/(\\|%)/@/;
		my $type = $route->get_target_type(
			'target' => $to,
		);
		my $dest = $route->get_route(
			'type' => $type,
			$type => $to,
		);
		if (defined $dest)
		{
			my $trow = $route->get_target(
				'type' => $type,
				$type => $to,
			);
			my $conv = new Ring::Conversation();
			my $cres = $conv->setup_conv(
				'media' => 'call',
				'from_user_id' => $fru->{'user_id'},
				#'from_conversation_uuid' => $uuid,
				'to_user_id' => $trow->data('user_id'),
				'to_user_target_id' => $trow->id(),
			);
			my ($cok, $newto, $newfrom, $touuid, $tocontact) = @$cres;
			#::log("Conv: ok:$cok to:$newto from:$newfrom to_uuid:$touuid to_contact:$tocontact");
			if ($cok eq 'ok')
			{
				my $tologin = $trow->row('user_id', 'ring_user')->data('login');
				::log("Lookup From: $fru->{'login'}|$newfrom -> To: $tologin|$to");
				$newfrom =~ s/\@/\\/;
				$newfrom = uri_escape($newfrom);
				$res = "type=phone;from=$newfrom;to=$dest->{'phone'};uuid=$touuid;contact=$tocontact";
			}
		}
		::log("Lookup Result: $res");
		#::log("From: $from To: $to", "Type: $type", "Dest: $res");
		#::log("From: $from To: $dest->{'phone'}");
	}
	elsif ($to =~ /^#([a-z0-9_]+)/i)
	{
		my $tag = lc($1);
		my $trow = new Note::Row(
			'ring_hashtag' => {
				'hashtag' => $tag,
			},
			'select' => ['target_url'],
		);
		my $url;
		if ($trow->id())
		{
			$url = $trow->data('target_url');
		}
		else
		{
			$url = 'http://'. $::app_config->{'www_domain'};
		}
		$res = "type=url;url=". encode_base64($url);
	}
	return $res;
}

1;

