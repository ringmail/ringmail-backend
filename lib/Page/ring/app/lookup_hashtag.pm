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
		if ($to =~ /^#([a-z0-9_]+)/i)
		{
			my $tag = $1;
			my $url;
			my $avatarImg = 'explore_hashtagdir_icon4.jpg';
			my $imgPath = '/img/hashtag_avatars/';

			# global hashtag lookup
			my $hq = sqltable('ring_hashtag')->get(
				'select' => ['target_url', 'user_id'],
				'where' => {
					'hashtag' => $tag,
					'localized' => 0,
				},
			);
			if (scalar @$hq)
			{
				$url = $hq->[0]->{'target_url'};
				if ($hq->[0]->{'user_id'} == 0 && $url =~ /^\//)
				{
					# interpret as a relative path (only for internal tags)
					$url = $obj->url('path' => $url);
				}
			}
			else
			{
				# localized hashtag,place search
				my $distance = 10; # Miles
				my $rangeFactor = 0.014457;
				my $avatarUrl;

				my $qtag = lc($1);
				$qtag = "\'$qtag\'";
				
				# TODO: Add global hashtags
				my $tq = sqltable('ring_hashtag')->get(
					'select' => [
						'g.business_place_id as place_id',
					],
					'table' => 'ring_hashtag_geo g, ring_hashtag h',
					'join' => 'h.id=g.hashtag_id',
					'where' => "h.hashtag=$qtag AND h.localized = 1 AND g.latitude BETWEEN $latIn-($distance*$rangeFactor) AND $latIn+($distance*$rangeFactor) AND g.longitude BETWEEN $lonIn-($distance*$rangeFactor) AND $lonIn+($distance*$rangeFactor) AND geodistance($latIn,$lonIn,g.latitude,g.longitude) <= $distance",
					'order' => "(POW((g.longitude-$lonIn),2) + POW((g.latitude-$latIn),2))",
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
					my $placequery = sqltable('ring_hashtag_geo')->get(
						'select' => 'g.business_place_id',
						'table' => 'ring_hashtag_geo g, ring_hashtag h',
						'join' => 'g.hashtag_id=h.id',
						'where' => {
							'h.hashtag' => $tag,
							'h.localized' => 1,
						},
						'order' => 'g.id asc limit 1',
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

