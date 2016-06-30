package Page::ring::setup::processing;

use strict;
use warnings;

use Moose;

use Note::Param;

use Ring::User;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $session = $self->session();
    my $content = $self->content();

    ::log( $session, );

    if ( defined $session->{'payment_attempt'} ) {

        my $payment_attempt_row = Note::Row->new( payment_attempt => $session->{payment_attempt}, );

        if ( $payment_attempt_row->id() ) {

            if ( $payment_attempt_row->data('result') ne 'processing' ) {

                return $self->redirect('/u/cart');
            }
        }
    }

    unless ( exists $session->{'payment_attempt'} ) {

        return $self->redirect('/u/processing');
    }

    return $self->SUPER::load($param);
}

1;
