package Page::ring::setup::ringpage;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

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
    $content->{edit} = ( $form->{'edit'} ) ? 1 : 0;

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
                user_id                 => $uid,
                id                      => $id,
                ringpage                => $data->{ringpage},
                header_background_color => $data->{header_background_color},
                header_text_color       => $data->{header_text_color},
                body_background_image   => $data->{body_background_image},
                body_background_color   => $data->{body_background_color},
                body_text_color         => $data->{body_text_color},
                footer_background_color => $data->{footer_background_color},
                footer_text_color       => $data->{footer_text_color},
                body_header             => $data->{body_header},
                body_text               => $data->{body_text},
                footer_text             => $data->{footer_text},
                header_title            => $data->{header_title},
                header_subtitle         => $data->{header_subtitle},
            )
            )
        {
            # display confirmation
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
