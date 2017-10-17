package Page::ring::business_places;

use strict;
use warnings;

use Moose;
use JSON::XS 'decode_json';
use List::Util 'sum';

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
	$content->{'hashtag'} = '#'. $hashtag;
	my $pq = sqltable('business_place')->get(
		'select' => [
			'p.*',
		],
		'table' => 'business_place p, business_hashtag_place h',
		'join' => 'h.place_id=p.id',
		'where' => { 'h.hashtag' => $hashtag, },
		'order' => 'p.id asc limit 11',
	);
	my @places = ();
	my @map_places = ();
	my @lat = ();
	my @lon = ();
	my $num = 0;
	foreach my $p (@$pq)
	{
		$p->{'number'} = ++$num;
		$p->{'name_filtered'} = $p->{'name'};
		$p->{'name_filtered'} =~ s/[^a-zA-Z0-9\- ]//gm;
		push @places, $p;
		if ($p->{'latitude'} != 0 && $p->{'longitude'} != 0)
		{
			push @map_places, $p;
			push @lat, $p->{'latitude'};
			push @lon, $p->{'longitude'};
		}
		last if (scalar(@places) == 10); # only keep 10, use #11 to check for next page
	}
	$content->{'places'} = \@places;
	$content->{'map_places'} = \@map_places;
	$content->{'mapbox_token'} = $obj->app()->config()->{'mapbox_token'};
	if (scalar @lat)
	{
		$content->{'avg_latitude'} = sum(@lat) / scalar(@lat);
		$content->{'avg_longitude'} = sum(@lon) / scalar(@lon);
	}
	::log($content);

	return $obj->SUPER::load($param);
}

1;

