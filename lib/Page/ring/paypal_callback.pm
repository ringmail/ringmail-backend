package Page::ring::paypal_callback;

use constant::boolean;
use Crypt::CBC;
use LWP::UserAgent;
use MIME::Base64 qw{ decode_base64 };
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

    my $form    = $self->form();
    my $request = $self->request();

    my $config = $main::note_config->config();

    my $paypal_hostname = $config->{paypal_hostname};
    my $paypal_key      = $config->{paypal_key};

    my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0, }, );

    my $req = HTTP::Request->new( POST => $paypal_hostname, );

    $req->content( join q{&}, $request->content(), 'cmd=_notify-validate', );
    $req->content_type( 'application/x-www-form-urlencoded', );
    $req->header( Host => 'www.paypal.com', );

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

            my $key       = $paypal_key;
            my $cipher    = 'Crypt::CBC'->new( -key => $key, );
            my $plaintext = $cipher->decrypt( decode_base64 $ciphertext_encoded, );

            my ( $user_id, $amount, @hashtag_ids, ) = map { hex; } split qr{ \s }xms, $plaintext;

            my $payment_gross = $form->{payment_gross};

            if ( $amount == hex sprintf '%X', $payment_gross ) {

                transaction(
                    acct_dst => ( has_account( $user_id, ) ) ? 'Note::Account'->new( $user_id, ) : create_account( $user_id, ),
                    acct_src => account_id( 'payment_paypal', ),
                    amount   => $amount,
                    tx_type  => tx_type_id( 'payment_paypal', ),
                    user_id  => $user_id,
                );

                for my $hashtag_id (@hashtag_ids) {

                    my $transaction_id = transaction(
                        acct_dst => account_id( 'revenue_ringmail', ),
                        acct_src => ( has_account( $user_id, ) ) ? 'Note::Account'->new( $user_id, ) : create_account( $user_id, ),
                        amount   => 99.99,
                        tx_type  => tx_type_id( 'purchase_hashtag', ),
                        user_id  => $user_id,
                    );

                    my $cart_row = Note::Row->new(
                        ring_cart => {
                            hashtag_id => $hashtag_id,
                            user_id    => $user_id,
                        },
                    );

                    my $hashtag_row = Note::Row->new(
                        ring_hashtag => {
                            id      => $hashtag_id,
                            user_id => $user_id,
                        },
                    );

                    if ( defined $cart_row->id() and defined $hashtag_row->id() ) {
                        $cart_row->update(
                            {

                                transaction_id => $transaction_id,

                            },
                        );

                        $hashtag_row->update(
                            {

                                paid => TRUE,

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
