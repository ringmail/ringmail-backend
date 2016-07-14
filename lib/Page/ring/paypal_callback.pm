package Page::ring::paypal_callback;

use Moose;
use Note::Param;
use strict;
use warnings;
use LWP::UserAgent;

extends 'Note::Page';

has 'user' => (
    'is'  => 'rw',
    'isa' => 'Ring::User',
);

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my ( $form_self, $form_param, ) = ( $self->form(), $param->{form}, );

    ::log( $self,      $param, );
    ::log( $form_self, $form_param, );

    my $request = $self->request();

    ::log( $request->content(), );

    my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0, }, );

    my $req = HTTP::Request->new( 'POST', 'https://ipnpb.sandbox.paypal.com/cgi-bin/webscr', );

    $req->content_type( 'application/x-www-form-urlencoded', );
    $req->header( Host => 'www.paypal.com', );
    $req->content( join q{&}, $request->content(), 'cmd=_notify-validate', );

    my $res = $ua->request($req);

    ::log( $res, );

    if ( $res->is_error ) {

    }

    if ( $res->content eq 'VERIFIED' ) {

        # check the $payment_status=Completed
        # check that $txn_id has not been previously processed
        # check that $receiver_email is your Primary PayPal email
        # check that $payment_amount/$payment_currency are correct
        # process payment

    }

    if ( $res->content eq 'INVALID' ) {

        # log for manual investigation
    }

    return $self->SUPER::load( $param, );
}

1;
