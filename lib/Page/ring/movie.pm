package Page::ring::movie;

use strict;
use warnings;

use Moose;
use JSON::XS 'decode_json';
use List::Util 'sum';
use Date::Parse 'str2time';
use POSIX 'strftime';

use Note::Row;
use Note::Param;
use Note::SQL::Table 'sqltable';

extends 'Note::Page';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	
	my $hashtag = $form->{'hashtag'};
	unless ($hashtag =~ /^([a-z0-9_]+)/i)
	{
		return '';
	}

	my $md = sqltable('movie')->get(
		'result' => 1,
		'where' => {'hashtag' => $hashtag},
	);
	unless ($md)
	{
		return '';
	}
	$hashtag = $md->{'hashtag'};
	
	$content->{'tag'} = $hashtag;
	$content->{'hashtag'} = '#'. $hashtag;
	$content->{'movie'} = $md;
	my $ts = str2time("$md->{'release_date'} 00:00:00");
	$content->{'release'} = strftime("%B %d, %Y", localtime($ts));
	return $obj->SUPER::load($param);
}

1;

