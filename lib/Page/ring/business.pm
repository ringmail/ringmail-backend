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
        'where' => { 'hashtag' => $hashtagIn, },
        'order' => 'id asc',
        );
        $placeId = ${$hashtagplaces->[0]}{'place_id'};
        if ($placeId) {
            $rec = new Note::Row('business_place' => {'id' => $placeId});
        }
    }

    if ($idIn)
    {
        $placeId = $idIn; 
        my $hashtagplaces = sqltable('business_hashtag_place')->get(
        'select' => 'hashtag',
        'where' => { 'place_id' => $placeId, },
        'order' => 'id asc',
        );
        $hashtag = "#" . ${$hashtagplaces->[0]}{'hashtag'};    
        $rec = new Note::Row('business_place' => {'id' => $placeId});
    }
    
    if ($rec)
    {
        $content->{'record'} = 'true';
        my $chainName = $rec->data('chain_name');
#        if ($chainName)
#        {
#            my $chainSocial = new Note::Row('business_chain_social' => {'chain_name' => $chainName});
#            $chainName =~ s/(\s|[^a-zA-Z0-9])//g;
#            $content->{'bodybg'} = $chainName;
#            my $logoImg = "./img/business/logo/$chainName.png";
#            my $logoRec = new Note::Row('business_logos' => {'name' => $chainName});
#            if ($logoRec->data('name'))
#            {
#                $content->{'logo'} = $logoImg;
#            }
#
#            ::log("htag chainName:  $chainName");
#        }

        my $tel = $rec->data('tel');
        $tel =~ s/^\+1(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;

        my $fax = $rec->data('fax');
        $fax =~ s/^\+1(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;

        $content->{'hashtag'} = $hashtag;
        $content->{'placeId'} = $placeId;

        $content->{'address'} = $rec->data('address');
        $content->{'address_extended'} = $rec->data('address_extended');
        $content->{'country'} = $rec->data('country');
        $content->{'email'} = $rec->data('email');
        $content->{'factual_id'} = $rec->data('factual_id');
        $content->{'fax'} = $fax;
        $content->{'hours_display'} = $rec->data('hours_display');
        $content->{'locality'} = $rec->data('locality');
        $content->{'name'} = $rec->data('name');
        $content->{'neighborhood'} = $rec->data('neighborhood');
        $content->{'po_box'} = $rec->data('po_box');
        $content->{'post_town'} = $rec->data('post_town');
        $content->{'postcode'} = $rec->data('postcode');
        $content->{'region'} = $rec->data('region');
        $content->{'tel'} = $tel;

        my $website = $rec->data('website');
        $content->{'websiteLink'} = $website;
        $website =~ s/^(http|https):\/\/www\.//;
        $website =~ s/\s+$//;
        $content->{'website'} = $website;
    }
  
    return $obj->SUPER::load($param);
}

1;

