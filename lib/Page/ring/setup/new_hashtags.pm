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
        select => [ qw{ rh.hashtag rh.id rc.hashtag_id }, ],
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

sub search {
    my ( $self, $form_data, $args, ) = @_;

    return if not length $form_data->{hashtag} > 0;

    $self->form()->{hashtag} = $form_data->{hashtag};

    my $hashtag_model = 'Ring::Model::Hashtag'->new();

    my $exists = $hashtag_model->check_exists( tag => $form_data->{hashtag}, );

    $self->value()->{hashtag} = $exists;

    if ( not $exists ) {

        my $user             = $self->user();
        my ( $ringpage_id, ) = ( $form_data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );
        my $tag              = lc $form_data->{hashtag};
        my $target           = $form_data->{target};

        if ( length $target > 0 ) {

            $target =~ s{ \A \s* }{}xms;    # trim whitespace
            $target =~ s{ \s* \z }{}xms;
            if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
                $target = "http://$target";
            }

        }

        if ( $hashtag_model->validate_tag( tag => $tag, ) ) {
            if ( $hashtag_model->check_exists( tag => $tag, ) ) {
                ::log('Dup');
            }
            else {

                my $hashtag = $hashtag_model->create(
                    category_id => $form_data->{category_id},
                    ringpage_id => $ringpage_id,
                    tag         => $tag,
                    target_url  => $target,
                    user_id     => $user->id(),
                );
                if ( defined $hashtag ) {

                    my $hashtag_id = $hashtag->id();

                    ::log( "New Hashtag: #$tag", );

                    my $cart = Note::Row::create(
                        ring_cart => {
                            hashtag_id => $hashtag_id,
                            user_id    => $user->id(),
                        },
                    );

                }
            }
        }

        return $self->redirect('/u/cart');
    }

    return;
}

sub remove_from_cart {
    my ( $self, $form_data, $args, ) = @_;

    my $user = $self->user();

    my ( $hashtag_id, ) = ( @{$args}, );

    my $hashtag_model = Ring::Model::Hashtag->new();

    if ($hashtag_model->delete(
            user_id => $user->id(),
            id      => $hashtag_id,
        )
        )
    {
        # display confirmation
    }
    else {
        # failed
    }

    return;
}

1;
