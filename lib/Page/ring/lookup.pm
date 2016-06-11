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
	if (defined $fru)
	{
		$from = $fru->{'login'};
		$from =~ s/\@/\\/;
		$from = uri_escape($from); # TODO: expand?
	}
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
			$res = "type=phone;from=$from;to=$dest->{'phone'}";
		}
		::log("From: $from", "To: $to", "Type: $type", "Dest: $res");
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

