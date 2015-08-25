package Page::ring::lookup;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::Route;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log($form);
	my $res = 'noentry';
	my $route = new Ring::Route();
	my $from = $form->{'from'};
	$from =~ s/^sip\://;
	$from =~ s/\@.*//g;
	my $fru = $route->get_from_user(
		'phone' => $from,
	);
	if (defined $fru)
	{
		$from = $fru->{'login'};
		#$from =~ s/\@/%/;
		$from = uri_escape($from);
	}
	my $to = $form->{'to'};
	$to =~ s/^sip\://;
	$to =~ s/\@.*//g;
	$to =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	my $target = {};
	if ($to =~ /%/)
	{
		$to =~ s/%/@/;
	}
	my $type = $route->get_target_type(
		'target' => $to,
	);
	my $dest = $route->get_route(
		'type' => $type,
		$type => $to,
	);
	if (defined $dest)
	{
		$res = "from=$from;to=$dest->{'phone'}";
	}
	::log("From: $from", "To: $to", "Type: $type", "Dest: $res");
	return $res;
}

1;

