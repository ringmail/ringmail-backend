package Page::ring::lookup;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log($form);
	my $res = 'noentry';
	my $from = $form->{'from'};
	my $to = $form->{'to'};
	$to =~ s/^sip\://;
	$to =~ s/\@.*//g;
	$res = "from=$from;to=$to";
	return $res;
}

1;

