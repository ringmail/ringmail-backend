package Page::ring::setup::new_hashtags;

use English '-no_match_vars';
use HTML::Entities 'encode_entities';
use JSON::XS 'encode_json';
use Moose;
use Note::Account qw{ account_id transaction tx_type_id };
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::Model::Category;
use Ring::Model::Hashtag;
use Ring::Model::RingPage;
use Ring::User;
use strict;
use warnings;

extends 'Page::ring::user';
extends 'Page::ring::setup::cart';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content        = $self->content();
    my $user           = $self->user();
    my $category_model = Ring::Model::Category->new();
    my $categories     = $category_model->list();
    my $ringpage_model = Ring::Model::RingPage->new();
    my $ringpages      = $ringpage_model->list( user_id => $user->id(), );

    my $hashtags = sqltable('ring_cart')->get(
        select => [ qw{ rh.hashtag rh.id rc.hashtag_id rc.transaction_id }, ],
        table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
        join   => 'rh.id = rc.hashtag_id',
        where  => [
            {   'rc.user_id' => $user->id(),
                'rh.user_id' => $user->id(),
            },
        ],
    );

    $content->{category_list} = [ map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories}, ];
    $content->{hashtags}      = $hashtags;
    $content->{ringpage_list} = [ map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages}, ];
    $content->{total}         = 99.99 * scalar @{$hashtags};

    return $self->SUPER::load( $param, );
}

1;
