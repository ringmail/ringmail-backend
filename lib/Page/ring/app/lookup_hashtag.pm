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
			my $imgPath = '/img/hashtag_avatars/';

			my $tag = $1;
			my $qtag = lc($1);
			$qtag = "\'$qtag\'";
			
			# TODO: Add global hashtags
			my $tq = sqltable('business_place_category_geo')->get(
				'select' => [
					'b.place_id',
					'p.hashtag',
				],
				'table' => 'business_place_category_geo b, business_hashtag_place p',
				'join' => 'b.place_id=p.place_id',
				'where' => "p.hashtag=$qtag AND b.latitude BETWEEN $latIn-($distance*$rangeFactor) AND $latIn+($distance*$rangeFactor) AND b.longitude BETWEEN $lonIn-($distance*$rangeFactor) AND $lonIn+($distance*$rangeFactor) AND geodistance($latIn,$lonIn,b.latitude,b.longitude) <= $distance",
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
				# check for a hashtag anywhere
				my $placequery = sqltable('business_hashtag_place')->get(
					'select' => 'h.place_id',
					'table' => 'business_hashtag_place h',
					'where' => {
						'h.hashtag' => $tag,
					},
					'order' => 'h.id asc limit 1',
				);
				if (scalar(@$placequery))
				{
					$url = $obj->url('path' => '/internal/ringpage/business_places?hashtag='. $tag);
				}
				else
				{
					# default
					$url = 'http://pages.ringmail.com/ringmail/hashtag_claimahashtag/';
				}
			}

			$res = {
				'result' => 'ok',
				'target' => $url,
				'img_path' => $imgPath,
				'avatar_img' => $avatarImg,
			};
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;

