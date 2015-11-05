package Page::ring::app::log;
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

use Ring::User;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $msg = $form->{'message'};
	chomp($msg);
	my $st = $Note::Log::start;
	my $start = join('.', $st->[0], sprintf("%06d", $st->[1]));
	$msg = "[$start] $msg\n";
	::log($msg);
	#::log($form);
	$obj->{'response'}->content_type('application/json');
	return encode_json({});
}

1;

