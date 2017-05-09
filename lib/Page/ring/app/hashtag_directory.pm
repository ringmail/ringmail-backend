package Page::ring::app::hashtag_directory;
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

	my $latIn = $form->{'lat'};
	my $lonIn = $form->{'lon'};
	my $distance = 1;
	my $rangeFactor = 0.014457;

	::log('hashtag directory', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {};
	if ($user)
	{
		my $width = int($form->{'width'});
		my $headerImg;
		my $headerHeight;
		my $cardHeaderImg;
		my $cardHeaderHeight;
		my $catimg;
		my $imgExt;

		if ($width eq '320')
		{
			$headerImg = '/img/hashtag_categories/temp/explore_banner_ip5.jpg';
			$headerHeight = '135';
			$cardHeaderImg = '/img/hashtag_categories/temp/explore_hashtag_category_sample_banner1_ip5.jpg';
			$cardHeaderHeight = '96';
			$catimg = '/img/hashtag_categories/temp/hashtagdir_ip5.jpg';
			$imgExt = '_ip5.jpg';
		}
		elsif ($width eq '375')
		{
			$headerImg = '/img/hashtag_categories/temp/explore_banner_ip6.jpg';
			$headerHeight = '158';
			$cardHeaderImg = '/img/hashtag_categories/temp/explore_hashtag_category_sample_banner1_ip6.jpg';
			$cardHeaderHeight = '113';
			$catimg = '/img/hashtag_categories/temp/hashtagdir_ip6.jpg';
			$imgExt = '_ip6.jpg';
		}
		elsif ($width eq '414')
		{
			$headerImg = '/img/hashtag_categories/temp/explore_banner_ip6p.jpg';
			$headerHeight = '174';
			$cardHeaderImg = '/img/hashtag_categories/temp/explore_hashtag_directory_sample_banner1_ip6p.jpg';
			$cardHeaderHeight = '124';
			$catimg = '/img/hashtag_categories/temp/hashtagdir_ip6p.jpg';
			$imgExt = '_ip6p.jpg';
		}
		else
		{
			$headerImg = '/img/hashtag_categories/temp/explore_banner_ip6.jpg';
			$headerHeight = '158';
			$cardHeaderImg = '/img/hashtag_categories/temp/explore_hashtag_category_sample_banner1_ip6.jpg';
			$cardHeaderHeight = '113';
			$catimg = '/img/hashtag_categories/temp/hashtagdir_ip6.jpg';
			$imgExt = '_ip6.jpg';
		}
		my $tmpCatImg = $catimg;
		my $tmpHeaderImg = $cardHeaderImg;

		my $pid = $form->{'category_id'};
		if ($pid =~ /^\d+$/)
		{

			if ($pid == 0) # root of directory
			{
				my $dq = sqltable('ring_category')->get(
					'select' => [
						'id',
						'category',
					],
					'where' => 'category_id IS NULL',
					'order' => 'category ASC', # TODO: custom order for top level
				);
				my @cat = ();
				foreach my $c (@$dq)
				{
					push @cat, {
						'type' => 'hashtag_category',
						'name' => $c->{'category'},
						'id' => $c->{'id'},
						'image_url' => $obj->url('path' => $catimg),
					};
				}

				# TODO: unroll this!
				my @group = ([]);
				my $max = 2;
				foreach my $i (@cat)
				{
					if (scalar(@{$group[-1]}) == $max)
					{
						push @group, [];
					}
					push @{$group[-1]}, $i;
				}
				foreach my $i (0..$#group)
				{
					$group[$i] = {
						'type' => 'hashtag_category_group',
						'group' => $group[$i],
					};
				}
				$res->{'directory'} = \@group;
				$res->{'header'} = {
					'type' => 'hashtag_directory_header',
					'image_url' => $obj->url('path' => $headerImg),
					'image_height' => $headerHeight,
					'category_name' => '',
					'parent_name' => '',
					'top_name' => '',
				};
				$res->{'result'} = 'ok';
				$obj->{'response'}->header('Cache-Control', 'max-age='. 3600);
			}
			else # sub-category or leaf
			{
#				my $dq = sqltable('business_category')->get(
#					'select' => [
#						'c1.id',
#						'c1.business_category_name',
#						'c1.parent',
#						'c2.parent c2Parent',
#						'c1.factual_category_id',
#						'c2.business_category_name as c2Name',
#						'c1.img_url',
#						'c1.header_img_url',
#					],
#					'table' => 'business_category c1, business_category c2',
#					'join' => 'c2.id=c1.parent',
#					'where' => "c1.parent=$pid",
#					'order' => 'business_category_name asc',
#				);
				my $dq = sqltable('ring_category')->get(
					'select' => [
						'id',
						'category',
						'category_id',
						'image_card',
						'image_header',
					],
					'where' => {
						'category_id' => $pid,
					},
					'order' => 'category asc',
				);
				my @cat = ();
				if (scalar @$dq) # has items, must be sub-category
				{
					foreach my $c (@$dq)
					{
						if ($c->{'image_card'} ne '')
						{
							$catimg = $c->{'image_card'}. $imgExt;
						}
						else
						{
							$catimg = $tmpCatImg;
						}
						push @cat, {
							'type' => 'hashtag_category',
							'name' => $c->{'category'},
							'id' => $c->{'id'},
							'image_url' => $obj->url('path' => $catimg),
						};
					}
					my @group = ([]);
					my $max = 2;
					foreach my $i (@cat)
					{
						if (scalar(@{$group[-1]}) == $max)
						{
							push @group, [];
						}
						push @{$group[-1]}, $i;
					}
					foreach my $i (0..$#group)
					{
						$group[$i] = {
							'type' => 'hashtag_category_group',
							'group' => $group[$i],
						};
					}
					$res->{'directory'} = \@group;
					my $pname = '';
					my $tname = '';
					my $curcat = new Note::Row('ring_category' => {'id' => $pid}, 'select' => ['category', 'category_id', 'image_header']);	
					if (defined $curcat->data('category_id'))
					{
						my $parcat = $curcat->row('category_id', 'ring_category');
						$pname = $parcat->data('category');
						if (defined $parcat->data('category_id'))
						{
							$tname = $parcat->row('category_id', 'ring_category')->data('category');
						}
					}
					if ($curcat->data('image_header') ne '')
					{
						$cardHeaderImg = $curcat->data('image_header'). $imgExt;
					}
					else
					{
						$cardHeaderImg = $tmpHeaderImg;
					}
					$res->{'header'} = {
						'type' => 'hashtag_directory_header',
						'image_url' => $obj->url('path' => $cardHeaderImg),
						'image_height' => $cardHeaderHeight,
						'category_name' => $curcat->data('category'),
						'parent_name' => $pname,
						'top_name' => $tname,
					};
					$res->{'result'} = 'ok';
					$obj->{'response'}->header('Cache-Control', 'max-age='. 3600);

				}
				else # no sub-categories, must be leaf so lookup hashtags
				{
				}
#				else
#				{
#					my $catrc = new Note::Row('business_category' => {'id' => $pid});
#					# my $catrc = sqltable('business_category')->get(
#					# 	'select' => [
#					# 		'bc1.id'
#					# 		'bc1.business_category_name',
#					# 		'bc2.business_category_name as parent_name'
#					# 	],
#					# 	'table' => 'business_category bc1, business_category bc2',
#					# 	'join' => 'bc2.id=bc1.parent',
#					# 	'where' => "bc1.id = $pid",
#					# );
#					if ($catrc->data('header_img_url'))
#					{
#						$cardHeaderImg = $catrc->data('header_img_url') . $imgExt;
#					}
#
#					if ($catrc->id())
#					{
#						my $parentrc = new Note::Row('business_category' => {'id' => $catrc->data('parent')});
#						if ($parentrc->id())
#						{
#							my @cat = (
#								{
#									'type' => 'hashtag_category_header',
#									'header_img_url' => $obj->url('path' => $cardHeaderImg),
#									'header_img_ht' => $cardHeaderHeight,
#									'name' => $catrc->data('business_category_name'),
#									'parent_name' => $parentrc->data('business_category_name'),
#									'id' => $pid,
#								}
#							);
#							my $tq = sqltable('business_place_category_geo')->get(
#								'select' => [
#									'bhp.hashtag',
#									'bpcg.category_id',
#									'bpcg.place_id',
#								],
#								'table' => 'business_place_category_geo bpcg, business_hashtag_place bhp',
#								'join' => 'bpcg.place_id=bhp.place_id',
#								'where' => "bpcg.category_id=$pid AND bpcg.latitude BETWEEN $latIn-($distance*$rangeFactor) AND $latIn+($distance*$rangeFactor) AND bpcg.longitude BETWEEN $lonIn-($distance*$rangeFactor) AND $lonIn+($distance*$rangeFactor) AND geodistance($latIn,$lonIn,bpcg.latitude,bpcg.longitude) <= $distance",
#								'order' => 'bhp.hashtag',
#							);
#
#							#::log($tq);
#
#							my %seen = ();
#
#							my $avatarImg = 'explore_hashtagdir_icon4.jpg';
#
#							foreach my $i (@$tq)
#							{
#								my $tag = '#'. $i->{'hashtag'};
#								push @cat, {
#									'type' => 'hashtag',
#									'label' => $tag,
#									'session_tag' => $tag,
#									'image' => $obj->url('path' => '/img/hashtag_avatars/'. $avatarImg),
#								};
#							}
#							$res->{'directory'} = \@cat;
#							$res->{'result'} = 'ok';
#						}
#					}
#				}
			}
		}
	}
	else
	{
		$res = {'result' => 'Unauthorized'};
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;
