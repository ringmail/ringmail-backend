package Page::ring::lookup_hashtag;

use strict;
use warnings;

use Moose;

use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

extends 'Note::Page';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $form = $self->form();

    my $url;

    if ( my ( $tag, ) = $form->{hashtag} =~ m{ \A ( \w+ ) \z }xmsi ) {

        my $hashtag = Note::Row->new(
            ring_hashtag => { hashtag => lc $tag, },
            select       => [ qw{ target_url ringpage_id }, ],
        );

        if ( $hashtag->id() ) {

            my $ringpage_id = $hashtag->data('ringpage_id');

            $url = do { length $hashtag->data('target_url') ? $hashtag->data('target_url') : undef; }
                // $self->url( path => '/ringpage/html', query => { ringpage_id => $ringpage_id, }, );

        }
        else {
            # default
            $url = 'http://' . $::app_config->{www_domain};
        }

    }

    return $self->redirect( $url, );
}

1;
