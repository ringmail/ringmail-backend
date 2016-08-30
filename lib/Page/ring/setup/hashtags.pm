package Page::ring::setup::hashtags;

use English '-no_match_vars';
use Moose;
use Note::Param;
use Note::SQL::Table 'sqltable';
use Ring::Model::Category;
use Ring::Model::RingPage;
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
        select    => [ qw{ ring_hashtag.hashtag ring_hashtag.id ring_cart.hashtag_id ring_cart.transaction_id ring_hashtag.target_url ring_hashtag.ringpage_id ring_page.ringpage }, ],
        table     => [ qw{ ring_cart ring_hashtag }, ],
        join      => 'ring_hashtag.id = ring_cart.hashtag_id',
        join_left => [ [ ring_page => 'ring_hashtag.ringpage_id = ring_page.id', ], ],
        where     => [
            {

                'ring_cart.user_id'    => $user->id(),
                'ring_hashtag.user_id' => $user->id(),

            },
        ],
    );

    $content->{category_list} = [ map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories}, ];
    $content->{hashtags}      = $hashtags;
    $content->{ringpage_list} = [ map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages}, ];

    return $self->SUPER::load( $param, );
}

sub remove {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my $hashtag_model = 'Ring::Model::Hashtag'->new();

    for my $hashtag_id ( $self->request()->parameters()->get_all( 'd5-hashtag_id', ) ) {

        if ($hashtag_model->delete(
                user_id => $user_id,
                id      => $hashtag_id,
            )
            )
        {

            my $cart_row = 'Note::Row'->new(
                ring_cart => {
                    hashtag_id => $hashtag_id,
                    user_id    => $user_id,
                },
            );

            if ( defined $cart_row->id() ) {

                $cart_row->delete();

            }
            else {

            }

            # display confirmation
        }
        else {
            # failed
        }
    }

    return;
}

sub directory {
    my ( $self, $form_data, $args, ) = @_;

    my $user            = $self->user();
    my ( $hashtag_id, ) = ( @{$args}, );
    my $user_id         = $user->id();

    my $directory_row = Note::Row::find_create( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, { ts_created => \'NOW()', }, );

    return;
}

1;
