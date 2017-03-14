package Page::ring::app::lookup_hashtag;
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
	::log('hashtag lookup', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};

	my $latIn = $form->{'lat'};
    my $lonIn = $form->{'lon'};

	if ($user)
	{
		my $to = $form->{'hashtag'};

		my $distance = 1;
    	my $rangeFactor = 0.014457;

		if ($to =~ /^#([a-z0-9_]+)/i)
		{
			my $url;
			my $avatarUrl;
			my $avatarImg = 'explore_hashtagdir_icon4.jpg';

			my $tag = lc($1);
			$tag = "\'$tag\'";
			
			my $tq = sqltable('business_place_category_geo')->get(
				'select' => [
					'b.place_id',
					'p.hashtag',
				],
				'table' => 'business_place_category_geo b, business_hashtag_place p',
				'join' => 'b.place_id=p.place_id',
				'where' => "p.hashtag=$tag AND b.latitude BETWEEN $latIn-($distance*$rangeFactor) AND $latIn+($distance*$rangeFactor) AND b.longitude BETWEEN $lonIn-($distance*$rangeFactor) AND $lonIn+($distance*$rangeFactor) AND geodistance($latIn,$lonIn,b.latitude,b.longitude) <= $distance",
				'order' => "(POW((b.longitude-$lonIn),2) + POW((b.latitude-$latIn),2))",
			);

			if (@$tq)
			{
				my $closestPlaceId = $$tq[0]->{'place_id'};
				$url = $obj->url('path' => 'ringpage_biz' . "?id=$closestPlaceId");
				$avatarUrl = '/img/hashtag_avatars/' . $avatarImg;
			}
			else
			{
				# default
				$url = 'http://pages.ringmail.com/ringmail/hashtag_claimahashtag/';
			}

			$res = {
				'result' => 'ok',
				'target' => $url,
				'avatar_url' => $avatarUrl,
			};
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;

