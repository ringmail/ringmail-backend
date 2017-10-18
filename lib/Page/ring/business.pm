package Page::ring::business;

use strict;
use warnings;

use Moose;
use JSON::XS 'decode_json';

use Note::Row;
use Note::Param;
use Note::SQL::Table 'sqltable';

extends 'Note::Page';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	
	my $idIn = $form->{'id'};
	my $hashtagIn = $form->{'hashtag'};
	my $rec;
	my $placeId;
	my $hashtag;

	if ($hashtagIn)
	{
		$hashtag = "#" . $hashtagIn;
		my $hashtagplaces = sqltable('business_hashtag_place')->get(
			'select' => 'place_id',
			'where' => {
				'hashtag' => $hashtagIn,
			},
			'order' => 'id asc',
		);
		$placeId = $hashtagplaces->[0]->{'place_id'};
		if ($placeId)
		{
			$rec = sqltable('business_place')->get(
				'result' => 1,
				'where' => {
					'id' => $placeId,
				},
			);
		}
	}

	if ($idIn)
	{
		$placeId = $idIn; 
		my $hashtagplaces = sqltable('business_hashtag_place')->get(
			'select' => 'hashtag',
			'where' => {
				'place_id' => $placeId,
			},
			'order' => 'id asc',
		);
		$hashtag = "#" . $hashtagplaces->[0]->{'hashtag'};
		$rec = sqltable('business_place')->get(
			'result' => 1,
			'where' => {
				'id' => $placeId,
			},
		);
	}

	if ($rec)
	{
		$content->{'record'} = 'true';
		my $chainName = $rec->{'chain_name'};
#		if ($chainName)
#		{
#			my $chainSocial = new Note::Row('business_chain_social' => {'chain_name' => $chainName});
#			$chainName =~ s/(\s|[^a-zA-Z0-9])//g;
#			$content->{'bodybg'} = $chainName;
#			my $logoImg = "./img/business/logo/$chainName.png";
#			my $logoRec = new Note::Row('business_logos' => {'name' => $chainName});
#			if ($logoRec->data('name'))
#			{
#				$content->{'logo'} = $logoImg;
#			}
#
#			::log("htag chainName:  $chainName");
#		}

		my $tel = $rec->{'tel'};
		$tel =~ s/^\+1(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;

		my $fax = $rec->{'fax'};
		$fax =~ s/^\+1(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;

		$content->{'hashtag'} = $hashtag;
		my $tag = $content->{'tag'} = substr($hashtag, 1);
		$content->{'placeId'} = $placeId;

		$content->{'address'} = $rec->{'address'};
		$content->{'address_extended'} = $rec->{'address_extended'};
		$content->{'country'} = $rec->{'country'};
		$content->{'email'} = $rec->{'email'};
		$content->{'factual_id'} = $rec->{'factual_id'};
		$content->{'fax'} = $fax;
		$content->{'hours_display'} = $rec->{'hours_display'};
		$content->{'locality'} = $rec->{'locality'};
		$content->{'name'} = $rec->{'name'};
		$content->{'neighborhood'} = $rec->{'neighborhood'};
		$content->{'po_box'} = $rec->{'po_box'};
		$content->{'post_town'} = $rec->{'post_town'};
		$content->{'postcode'} = $rec->{'postcode'};
		$content->{'region'} = $rec->{'region'};
		$content->{'latitude'} = $rec->{'latitude'};
		$content->{'longitude'} = $rec->{'longitude'};
		$content->{'tel'} = $tel;

		$content->{'mapbox_token'} = $obj->app()->config()->{'mapbox_token'};

		my $haslink = 0;
		my $website = $rec->{'website'};
		if (defined($website) && length($website))
		{
			$content->{'websiteLink'} = $website;
			$website =~ s/^(http|https):\/\/www\.//;
			$website =~ s/\s+$//;
			$content->{'website'} = $website;
			$haslink = 1;
		}

		$content->{'name_filtered'} = $rec->{'name'};
		$content->{'name_filtered'} =~ s/[^a-zA-Z0-9\- ]//gm;

		my $social = sqltable('business_social')->get(
			'result' => 1,
			'select' => ['facebook_url', 'twitter_url'],
			'where' => {
				'factual_id' => $rec->{'factual_id'},
			},
		);
		if ($social)
		{
			chomp($social->{'facebook_url'});
			chomp($social->{'twitter_url'});
			$content->{'social_facebook'} = $social->{'facebook_url'};
			$content->{'social_twitter'} = $social->{'twitter_url'};
			if (
				(defined($social->{'facebook_url'}) && length($social->{'facebook_url'})) ||
				(defined($social->{'twitter_url'}) && length($social->{'twitter_url'}))
			) {
				$haslink = 1;
			}
		}
		my $logopath = $main::note_config->{'root'}. '/app/ringmail/static/img/business/logo/'. lc($tag). '.png';
		if (-e $logopath)
		{
			$content->{'custom_logo'} = lc($tag). '.png';
		}

		$content->{'has_link'} = $haslink;
	}
  
	return $obj->SUPER::load($param);
}

1;

