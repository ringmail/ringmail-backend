package Page::ring::setup::ringpage;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use List::MoreUtils 'each_arrayref';

use Note::XML 'xml';
use Note::Param;
use Note::SQL::Table 'sqltable';

use Ring::User;
use Ring::Model::RingPage;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my $content = $obj->content();
    my $form    = $obj->form();
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $id      = $form->{'id'};
    if ( not $id =~ m{ \A \d+ \z }xms ) {
        return $obj->redirect('/u/ringpages');
    }
    my $ht = Note::Row->new(
        ring_page => {
            id      => $id,
            user_id => $uid,
        },
    );

    if ( not $ht->id() ) {
        return $obj->redirect('/u/ringpages');
    }
    $content->{ringpage} = $ht->data();
    ::log( $content->{ringpage}, );
    $content->{edit} = ( $form->{edit} ) ? 1 : 0;

    my $ringpage_id = $obj->form()->{id};

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ qw{ id button uri }, ],
        where  => { ringpage_id => $ringpage_id, },
    );

    $obj->content()->{ringpage}->{buttons} = $buttons;

    return $obj->$next( $param, );
};

sub edit {
    my ( $obj, $data, $args ) = @_;
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $id      = $args->[0];
    my $factory = Ring::Model::RingPage->new();
    if ( $factory->validate_ringpage( ringpage => $data->{ringpage}, ) ) {
        if ($factory->update(
                body_background_color   => $data->{body_background_color},
                body_background_image   => $data->{body_background_image},
                body_header             => $data->{body_header},
                body_text               => $data->{body_text},
                body_text_color         => $data->{body_text_color},
                footer_background_color => $data->{footer_background_color},
                footer_text             => $data->{footer_text},
                footer_text_color       => $data->{footer_text_color},
                header_background_color => $data->{header_background_color},
                header_subtitle         => $data->{header_subtitle},
                header_text_color       => $data->{header_text_color},
                header_title            => $data->{header_title},
                id                      => $id,
                offer                   => defined $data->{offer} ? 1 : 0,
                ringpage                => $data->{ringpage},
                user_id                 => $uid,
                video                   => defined $data->{video} ? 1 : 0,
            )
            )
        {
            # display confirmation

            my $each_array = each_arrayref [ $obj->request()->parameters()->get_all( 'd1-button_id', ), ], [ $obj->request()->parameters()->get_all( 'd1-button_text', ), ], [ $obj->request()->parameters()->get_all( 'd1-button_link', ), ];
            while ( my ( $button_id, $button_text, $button_link, ) = $each_array->() ) {

                ::log( $button_id, $button_text, $button_link, );

                if ( $button_id eq q{} ) {

                    next if $button_text eq q{} or $button_link eq q{};

                    my $row = Note::Row::create(
                        ring_button => {
                            button      => $button_text,
                            ringpage_id => $id,
                            uri         => $button_link,
                            user_id     => $user->id(),
                        },
                    );

                }

                else {

                    my $row = Note::Row->new( ring_button => $button_id, );

                    if ( $button_text eq q{} or $button_link eq q{} ) {

                        $row->delete();

                    }

                    else {

                        $row->update( { button => $button_text, uri => $button_link, }, );

                    }

                }

            }

        }
        else {
            # failed
        }
    }
    else {
        # invalid
    }

    return;
}

1;
