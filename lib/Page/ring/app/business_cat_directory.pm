package Page::ring::app::business_cat_directory;
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

	my $parentIdIn = $form->{'parent'};
	my $latIn = $form->{'lat'};
	my $lonIn = $form->{'lon'};
	my $distance = 1;
	my $rangeFactor = 0.014457;

	::log('business category directory', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'Unauthorized'};
	if ($user)
	{
		my $width = int($form->{'width'});
		my $headerImg;
		my $headerHeight;
		my $cardHeaderImg;
		my $cardHeaderHeight;

		if ($width eq '320')
		{
			$headerImg = 'explore_banner_ip5p@2x.png';
			$headerHeight = '135';
			$cardHeaderImg = 'explore_hashtag_category_sample_banner1_ip5@2x.jpg';
			$cardHeaderHeight = '96'
		}
		elsif ($width eq '375')
		{
			$headerImg = 'explore_banner_ip6-7s@2x.png';
			$headerHeight = '158';
			$cardHeaderImg = 'explore_hashtag_category_sample_banner1_ip6-7s@2x.jpg';
			$cardHeaderHeight = '113'
		}
		elsif ($width eq '414')
		{
			$headerImg = 'explore_banner_ip6-7p@3x.png';
			$headerHeight = '174';
			$cardHeaderImg = 'explore_hashtag_directory_sample_banner1_ip6-7p@3x.jpg';
			$cardHeaderHeight = '124'
		}
		else
		{
			$headerImg = 'explore_banner_ip6-7s@2x.png';
			$headerHeight = '158';
		}

		my $pid = $form->{'parent'};
		if ($pid =~ /^\d+$/)
		{
			if ($pid == 0)
			{
				my $dq = sqltable('business_category')->get(
					'select' => [
						'c1.id',
						'c1.business_category_name',
						'c1.parent',
						'c1.factual_category_id',
					],
					'table' => 'business_category c1',
					'where' => 'c1.parent IS NULL and c1.factual_category_id IS NULL',
					'order' => 'business_category_name asc',
				);

				my @cat = ();
				my $first = 1;

				foreach my $c (@$dq)
				{
					next if ($c->{'business_category_name'} =~ /\(none\)/i);
					my $catimg = 'hashtagdir.jpg';
					if ($first)
					{
						push @cat, {
							'type' => 'hashtag_category',
							'name' => $c->{'business_category_name'},
							'parent_name' => '',
							'parent2parent_name' => '',
							'id' => $c->{'id'},
							'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
							'header_type' => 'hashtag_directory_header',
							'header_img_url' => $obj->url('path' => '/img/hashtag_categories/'. $headerImg),
							'header_img_ht' => $headerHeight,
						};
						$first = 0;
					}
					else
					{
						push @cat, {
							'type' => 'hashtag_category',
							'name' => $c->{'business_category_name'},
							'id' => $c->{'id'},
							'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
						};
					}

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
				$res->{'result'} = 'ok';
				$obj->{'response'}->header('Cache-Control', 'max-age='. 3600);
			}
			else
			{
				my $dq = sqltable('business_category')->get(
					'select' => [
						'c1.id',
						'c1.business_category_name',
						'c1.parent',
						'c2.parent c2Parent',
						'c1.factual_category_id',
						'c2.business_category_name as c2Name',
					],
					'table' => 'business_category c1, business_category c2',
					'join' => 'c2.id=c1.parent',
					'where' => "c1.parent=$pid",
					'order' => 'business_category_name asc',
				);
				my @cat = ();

				if (@$dq) {
					my $first = 1;
					foreach my $c (@$dq)
					{
						my $catimg = 'hashtagdir.jpg';
						if ($first)
						{
							my $parentName = $c->{'c2Name'};
							my $parent2ParentName = '';

							if ($c->{'c2Parent'} ne '')
							{
								my $p2prc = new Note::Row('business_category' => {'id' => $c->{'c2Parent'}});
								if ($p2prc->id())
								{
									$parent2ParentName = $p2prc->data('business_category_name');
								}
							}
							
							push @cat, {
								'type' => 'hashtag_category',
								'name' => $c->{'business_category_name'},
								'parent_name' => $parentName,
								'parent2parent_name' => $parent2ParentName,
								'id' => $c->{'id'},
								'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
								'header_type' => 'hashtag_directory_header',
								'header_img_url' => $obj->url('path' => '/img/hashtag_categories/'. $cardHeaderImg),
								'header_img_ht' => $cardHeaderHeight,
							};
							$first = 0;
						}
						else
						{
							push @cat, {
								'type' => 'hashtag_category',
								'name' => $c->{'business_category_name'},
								'id' => $c->{'id'},
								'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
							};
						}
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
					$res->{'result'} = 'ok';
					$obj->{'response'}->header('Cache-Control', 'max-age='. 3600);

				}
				else
				{
					my $catrc = new Note::Row('business_category' => {'id' => $pid});
					# my $catrc = sqltable('business_category')->get(
					# 	'select' => [
					# 		'bc1.id'
					# 		'bc1.business_category_name',
					# 		'bc2.business_category_name as parent_name'
					# 	],
					# 	'table' => 'business_category bc1, business_category bc2',
					# 	'join' => 'bc2.id=bc1.parent',
					# 	'where' => "bc1.id = $pid",
					# );

					if ($catrc->id())
					{
						my $parentrc = new Note::Row('business_category' => {'id' => $catrc->data('parent')});
						if ($parentrc->id())
						{
							my @cat = (
								{
									'type' => 'hashtag_category_header',
									'header_img_url' => $obj->url('path' => '/img/hashtag_categories/'. $cardHeaderImg),
									'header_img_ht' => $cardHeaderHeight,
									'name' => $catrc->data('business_category_name'),
									'parent_name' => $parentrc->data('business_category_name'),
									'id' => $pid,
								}
							);
							my $tq = sqltable('business_place_category_geo')->get(
								'select' => [
									'bhp.hashtag',
									'bpcg.category_id',
									'bpcg.place_id',
								],
								'table' => 'business_place_category_geo bpcg, business_hashtag_place bhp',
								'join' => 'bpcg.place_id=bhp.place_id',
								'where' => "bpcg.category_id=$pid AND bpcg.latitude BETWEEN $latIn-($distance*$rangeFactor) AND $latIn+($distance*$rangeFactor) AND bpcg.longitude BETWEEN $lonIn-($distance*$rangeFactor) AND $lonIn+($distance*$rangeFactor) AND geodistance($latIn,$lonIn,bpcg.latitude,bpcg.longitude) <= $distance",
								'order' => 'bhp.hashtag',
							);

							::log($tq);

							my %seen = ();

							my $avatarImg = 'explore_hashtagdir_icon4.jpg';

							foreach my $i (@$tq)
							{
								my $tag = '#'. $i->{'hashtag'};
								push @cat, {
									'type' => 'hashtag',
									'label' => $tag,
									'session_tag' => $tag,
									'image' => $obj->url('path' => '/img/hashtag_avatars/'. $avatarImg),
								};
							}
							$res->{'directory'} = \@cat;
							$res->{'result'} = 'ok';
						}
					}
				}
			}
	
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;
