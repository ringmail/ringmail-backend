package Page::ring::paypal_callback;

use Crypt::CBC;
use JSON::XS qw{ encode_json decode_json };
use LWP::UserAgent;
use MIME::Base64;
use Moose;
use Note::Account qw{ account_id transaction tx_type_id has_account create_account };
use Note::Param;
use Note::Row;
use strict;
use warnings;

extends 'Note::Page';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $request = $self->request();
    my $form    = $self->form();

    my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0, }, );
    my $req = HTTP::Request->new( 'POST', 'https://ipnpb.sandbox.paypal.com/cgi-bin/webscr', );

    $req->content_type( 'application/x-www-form-urlencoded', );
    $req->header( Host => 'www.paypal.com', );
    $req->content( join q{&}, $request->content(), 'cmd=_notify-validate', );

    my $res = $ua->request( $req, );

    if ( $res->is_error ) {

    }

    if ( $res->content eq 'VERIFIED' ) {

        # check the $payment_status=Completed
        # check that $txn_id has not been previously processed
        # check that $receiver_email is your Primary PayPal email
        # check that $payment_amount/$payment_currency are correct
        # process payment

        my $ciphertext_encoded = $form->{custom};

        if ( defined $ciphertext_encoded and length $ciphertext_encoded > 0 ) {

            my $config    = $main::note_config->config();
            my $key       = $config->{paypal_key};
            my $cipher    = 'Crypt::CBC'->new( -key => $key, );
            my $plaintext = $cipher->decrypt( decode_base64 $ciphertext_encoded, );

            my ( $user_id, $amount, @hashtag_ids, ) = @{ decode_json $plaintext };

            my $payment_gross = $form->{payment_gross};

            if ( $amount == $payment_gross ) {

                for my $hashtag_id (@hashtag_ids) {

                    my $src = Note::Account->new( $user_id, );
                    my $dst = account_id('revenue_ringmail');

                    my $transaction_id = transaction(
                        acct_dst => $dst,
                        acct_src => $src,
                        amount   => 99.99,                            # TODO fix
                        tx_type  => tx_type_id('purchase_hashtag'),
                        user_id  => $user_id,
                    );

                    my $cart = Note::Row->new(
                        ring_cart => {
                            hashtag_id => $hashtag_id,
                            user_id    => $user_id,
                        },
                    );

                    if ( $cart->id() ) {
                        $cart->update(
                            {

                                transaction_id => $transaction_id,

                            },
                        );
                    }

                }

            }

        }
    }

    if ( $res->content eq 'INVALID' ) {

        # log for manual investigation
    }

    return $self->SUPER::load( $param, );
}

1;
