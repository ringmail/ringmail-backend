package Page::ring::setup::cart;

use constant::boolean;
use English '-no_match_vars';
use JSON::XS qw{ encode_json decode_json };
use LWP::UserAgent;
use Moose;
use Note::Account qw{ account_id transaction tx_type_id has_account create_account };
use Note::Param;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'whitespace';
use Ring::Model::Hashtag;
use Try::Tiny;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param(@args);

    my $user     = $self->user();
    my $form     = $self->form();
    my $_session = $self->_session();

    my $user_id = $user->id();

    my ( $payer_id, $payment_id, ) = ( $form->{PayerID}, $form->{paymentId}, );

    if ( defined $payer_id and defined $payment_id ) {

        my $config = $main::note_config->config();

        my $username = $config->{paypal_username};
        my $password = $config->{paypal_password};
        my $uri      = $config->{paypal_hostname};

        my $headers = 'HTTP::Headers'->new();

        $headers->authorization_basic( $username, $password, );

        my $request = 'HTTP::Request'->new( POST => "$uri/v1/oauth2/token", $headers, q{grant_type=client_credentials}, );

        my $ua = 'LWP::UserAgent'->new;

        my $response = $ua->request( $request, );

        my $access_token;
        my $token_type;

        if ( $response->is_success ) {

            my $response_content = decode_json $response->content;

            $access_token = $response_content->{access_token};
            $token_type   = $response_content->{token_type};

            my $dbh = $_session->database()->handle()->_dbh();

            my $auto_commit = $dbh->{AutoCommit};

            $dbh->{AutoCommit} = FALSE;    # enable transactions, if possible

            try {

                my $order_row = Note::Row::find_create( ring_order => { user_id => $user_id, transaction_id => undef, }, );

                my $order_id = $order_row->id();

                if ( defined $order_id ) {

                    my $order_total = $order_row->data('total');

                    my $hashtags = sqltable('ring_cart')->get(
                        select    => [ qw{ rc.id rc.hashtag_id rc.coupon_id rh.hashtag c.code c.amount }, ],
                        table     => 'ring_cart AS rc',
                        join_left => [

                            [ 'ring_hashtag AS rh' => 'rh.id = rc.hashtag_id', ],
                            [ 'coupon AS c'        => 'c.id = rc.coupon_id', ],
                        ],
                        where => [ { 'rc.user_id' => $user_id, } => and => { 'rc.transaction_id' => undef, }, ],
                    );

                    my $total = 0;

                    for my $hashtag ( @{$hashtags} ) {

                        my $amount = $hashtag->{amount};

                        my $hashtag_id = $hashtag->{hashtag_id};
                        my $coupon_id  = $hashtag->{coupon_id};

                        if ( defined $hashtag_id ) {

                            $amount //= 99.99;

                            my $account_destination = account_id( 'revenue_ringmail', );
                            my $account_source      = has_account( $user_id, ) ? 'Note::Account'->new( $user_id, ) : create_account( $user_id, );
                            my $tx_type_id          = tx_type_id( 'purchase_hashtag', );

                            my $transaction_id = transaction(
                                acct_dst => $account_destination,
                                acct_src => $account_source,
                                amount   => $amount,
                                tx_type  => $tx_type_id,
                                user_id  => $user_id,
                            );

                            my $cart_row = 'Note::Row'->new(
                                ring_cart => {
                                    hashtag_id => $hashtag_id,
                                    user_id    => $user_id,
                                },
                            );

                            my $hashtag_row = 'Note::Row'->new(
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

                            $total += $amount;

                        }

                        if ( defined $coupon_id ) {

                            my $account_source      = account_id('coupon_source');
                            my $account_destination = account_id('coupon_destination');
                            my $tx_type_id          = tx_type_id('coupon');

                            my $transaction_id = transaction(
                                acct_dst => $account_destination,
                                acct_src => $account_source,
                                amount   => $amount,
                                tx_type  => $tx_type_id,
                                user_id  => $user_id,
                            );

                            my $cart_row = 'Note::Row'->new(
                                ring_cart => {
                                    coupon_id => $coupon_id,
                                    user_id   => $user_id,
                                },
                            );

                            my $coupon_row = 'Note::Row'->new( coupon => { id => $coupon_id, }, );

                            if ( defined $cart_row->id() and defined $coupon_row->id() ) {
                                $cart_row->update(
                                    {

                                        transaction_id => $transaction_id,

                                    },
                                );

                                $coupon_row->update(
                                    {

                                        transaction_id => $transaction_id,
                                        user_id        => $user_id,

                                    },
                                );
                            }

                            $total -= $amount;

                        }

                    }

                    $total = sprintf '%.2f', $total;

                    if ( $order_total eq $total ) {

                        my $transaction_id = transaction(
                            acct_dst => ( has_account( $user_id, ) ) ? 'Note::Account'->new( $user_id, ) : create_account( $user_id, ),
                            acct_src => account_id( 'payment_paypal', ),
                            amount   => $total,
                            tx_type  => tx_type_id( 'payment_paypal', ),
                            user_id  => $user_id,
                        );

                        $order_row->update( { transaction_id => $transaction_id, }, );

                        my $headers = 'HTTP::Headers'->new( Authorization => "$token_type $access_token", );

                        $headers->content_type( 'application/json', );

                        my $request = 'HTTP::Request'->new(
                            POST => "$uri/v1/payments/payment/$payment_id/execute",
                            $headers, encode_json { payer_id => $payer_id, }
                        );

                        my $ua = 'LWP::UserAgent'->new;

                        my $response = $ua->request( $request, );

                        if ( $response->is_success ) {

                            my $response_content = decode_json $response->content;

                            my $transactions = $response_content->{transactions};

                            my ( $transaction, ) = ( @{$transactions}, );

                            my $amount = $transaction->{amount};

                            my $paypal_total = $amount->{total};

                            if ( $paypal_total eq $total ) {

                                $dbh->commit;    # commit the changes if we get this far

                            }
                            else {

                                eval { $dbh->rollback };

                            }

                        }

                    }
                    else {

                        eval { $dbh->rollback };

                    }

                }
                if ($@) {
                    warn "Transaction aborted because $@";

                    # now rollback to undo the incomplete changes
                    # but do it in an eval{} as it may also fail
                    eval { $dbh->rollback };

                    # add other application on-error-clean-up code here
                }

                return $self->redirect( $self->url( path => 'u', ), );
            }
            catch {

                my $error = $ARG;

                ::log( $error, );

                return undef;
            };

            $dbh->{AutoCommit} = $auto_commit;

        }

    }

    my $total = 0;

    my $hashtags = sqltable('ring_cart')->get(
        select    => [ qw{ rc.hashtag_id rc.coupon_id rh.hashtag c.code c.amount }, ],
        table     => 'ring_cart AS rc',
        join_left => [

            [ 'ring_hashtag AS rh' => 'rh.id = rc.hashtag_id', ],
            [ 'coupon AS c'        => 'c.id = rc.coupon_id', ],
        ],
        where => [ { 'rc.user_id' => $user_id, } => and => { 'rc.transaction_id' => undef, }, ],
    );

    for my $hashtag ( @{$hashtags} ) {

        if ( defined $hashtag->{hashtag_id} ) {

            $hashtag->{amount} //= 99.99;

            $total += $hashtag->{amount};

        }

        if ( defined $hashtag->{coupon_id} ) {

            $total -= $hashtag->{amount};

        }

    }

    my $content = $self->content();

    $content->{payment} = $self->show_payment_form();
    $content->{cartX}   = $hashtags;
    $content->{total}   = $total;

    return $self->SUPER::load( $param, );
}

sub search {
    my ( $self, $form_data, $args, ) = @_;

    my $user     = $self->user();
    my $user_id  = $user->id();
    my ( $tag, ) = ( lc( $form_data->{hashtag} ) =~ m{ ( [\s\w\#\,\-]+ ) }xms, );
    my ( $category_id, ) = ( $form_data->{category_id} // q{} =~ m{ \A ( \d+ ) \z }xms, );
    my ( $ringpage_id, ) = ( $form_data->{ringpage_id} // q{} =~ m{ \A ( \d+ ) \z }xms );
    my $target = $form_data->{target} // q{};

    return if not defined $tag;

    $tag =~ s{ [_\#\,\-]+ }{ }gxms;
    $tag =~ s{$RE{ws}{crop}}{}gxms;
    $tag =~ s{ \s+ }{_}gxms;

    return if not length $tag > 0;

    if ( length $tag > 140 ) {

        return;
    }

    $self->form()->{hashtag} = $tag;

    my $hashtag_model = 'Ring::Model::Hashtag'->new();

    my $exists = $hashtag_model->check_exists( tag => $tag, );

    $self->value()->{hashtag} = $exists;

    if ( not $exists ) {

        if ( length $target > 0 ) {

            $target =~ s{ \A \s* }{}xms;    # trim whitespace
            $target =~ s{ \s* \z }{}xms;
            if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
                $target = "http://$target";
            }

        }

        if ( $hashtag_model->validate_tag( tag => $tag, ) ) {

            my $hashtag = $hashtag_model->create(
                category_id => $category_id,
                ringpage_id => $ringpage_id,
                tag         => $tag,
                target_url  => $target,
                user_id     => $user_id,
            );
            if ( defined $hashtag ) {

                my $hashtag_id = $hashtag->id();

                my $cart = Note::Row::create(
                    ring_cart => {
                        hashtag_id => $hashtag_id,
                        user_id    => $user_id,
                    },
                );

            }
        }

        return $self->redirect( $self->url( path => join( q{/}, qw{ u cart }, ), ), );
    }

    return;
}

sub remove_from_cart {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my $hashtag_model = 'Ring::Model::Hashtag'->new();

    for my $hashtag_id ( $self->request()->parameters()->get_all( 'd4-hashtag_id', ) ) {

        if ($hashtag_model->delete(
                user_id => $user_id,
                id      => $hashtag_id,
            )
            )
        {
            # display confirmation
        }
        else {
            # failed
        }
    }

    return;
}

sub apply_coupon_code {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my ( $coupon_code, ) = ( $form_data->{coupon_code} =~ m{ \A ( [[:alpha:]]{4} [[:digit:]]{4} ) \z }xms, );

    my $coupon_row = 'Note::Row'->new(
        coupon => {
            code           => $coupon_code,
            transaction_id => undef,
            user_id        => undef,
        },
    );

    my $coupon_id = $coupon_row->id();

    if ( defined $coupon_id ) {

        my $cart = Note::Row::create(
            ring_cart => {
                coupon_id => $coupon_id,
                user_id   => $user_id,
            },
        );

    }

    return $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );
}

sub payment {
    my ( $self, $form_data, $args, ) = @_;

    my $user = $self->user();

    my $user_id = $user->id();

    my $config = $main::note_config->config();

    my $username = $config->{paypal_username};
    my $password = $config->{paypal_password};
    my $uri      = $config->{paypal_hostname};

    my $headers = 'HTTP::Headers'->new();

    $headers->authorization_basic( $username, $password, );

    my $request = 'HTTP::Request'->new( POST => "$uri/v1/oauth2/token", $headers, q{grant_type=client_credentials}, );

    my $ua = 'LWP::UserAgent'->new;

    my $response = $ua->request( $request, );

    my $access_token;
    my $token_type;

    if ( $response->is_success ) {

        my $response_content = decode_json $response->content;

        $access_token = $response_content->{access_token};
        $token_type   = $response_content->{token_type};

        my $headers = 'HTTP::Headers'->new( Authorization => "$token_type $access_token", );

        $headers->content_type( 'application/json', );

        my $return_url = $self->redirect( $self->url( path => 'u', ), );
        my $cancel_url = $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );

        my $order_row = Note::Row::find_create( ring_order => { user_id => $user_id, transaction_id => undef, }, );

        my $order_id = $order_row->id();

        if ( defined $order_id ) {

            my $hashtags = sqltable('ring_cart')->get(
                select    => [ qw{ rc.id rc.hashtag_id rc.coupon_id rh.hashtag c.code c.amount }, ],
                table     => 'ring_cart AS rc',
                join_left => [

                    [ 'ring_hashtag AS rh' => 'rh.id = rc.hashtag_id', ],
                    [ 'coupon AS c'        => 'c.id = rc.coupon_id', ],
                ],
                where => [ { 'rc.user_id' => $user_id, } => and => { 'rc.transaction_id' => undef, }, ],
            );

            my $total = 0;

            for my $hashtag ( @{$hashtags} ) {

                if ( defined $hashtag->{hashtag_id} ) {

                    $hashtag->{amount} //= 99.99;

                    $total += $hashtag->{amount};

                }

                if ( defined $hashtag->{coupon_id} ) {

                    $total -= $hashtag->{amount};

                }

                my $cart_row = 'Note::Row'->new( ring_cart => $hashtag->{id}, );

                $cart_row->update( { order_id => $order_id, }, );

            }

            $total = sprintf '%.2f', $total;

            $order_row->update( { total => $total, }, );

            my %cart = (

                intent        => 'sale',
                redirect_urls => {
                    return_url => $return_url,
                    cancel_url => $cancel_url,
                },
                payer        => { payment_method => 'paypal', },
                transactions => [
                    {   amount => {
                            total    => $total,
                            currency => 'USD',
                        },
                    },
                ],

            );

            my $request = 'HTTP::Request'->new(
                POST => "$uri/v1/payments/payment",
                $headers, encode_json \%cart,
            );

            my $ua = 'LWP::UserAgent'->new;

            my $response = $ua->request( $request, );

            if ( $response->is_success ) {

                my $response_content = decode_json $response->content;

                my ( $link_self, $link_approval_url, $link_execute, ) = ( @{ $response_content->{links} }, );

                my $redirect = $link_approval_url->{href};

                return $self->redirect( $redirect, );

            }

        }

    }

    return;
}

1;
