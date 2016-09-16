package Page::ring::setup::cart;

use constant::boolean;
use English '-no_match_vars';
use JSON::XS qw{ encode_json decode_json };
use LWP::UserAgent;
use Moose;
use Note::Account qw{ account_id transaction tx_type_id has_account create_account };
use Note::Check;
use Note::Param;
use Note::Payment;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'whitespace';
use Ring::Model::Hashtag;
use Try::Tiny;

extends 'Page::ring::user';

my %payment_check = (
    'first_name' => Note::Check->new(
        'type'  => 'regex',
        'chars' => 'A-Za-z0-9.- ',
    ),
    'last_name' => Note::Check->new(
        'type'  => 'regex',
        'chars' => 'A-Za-z0-9.- ',
    ),
    'address' => Note::Check->new(
        'type'  => 'regex',
        'chars' => 'A-Za-z0-9.- #/',
    ),
    'address2' => Note::Check->new(
        'type'        => 'regex',
        'chars_empty' => TRUE,
        'chars'       => 'A-Za-z0-9.- #/',
    ),
    'city' => Note::Check->new(
        'type'  => 'regex',
        'chars' => 'A-Za-z.- ',
    ),
    'zip' => Note::Check->new(
        'type'  => 'regex',
        'regex' => qr{ \A \d{5} \z }xms,
    ),
    'state' => Note::Check->new(
        'type'  => 'valid',
        'valid' => sub {
            my ( $sp, $data, ) = @_;
            unless ( exists $Note::Locale::states{ ${$data} } ) {
                Note::Check::fail('Invalid state');
            }
        },
    ),
    'phone' => Note::Check->new(
        'type'  => 'valid',
        'valid' => sub {
            my ( $sp, $data ) = @_;
            my $ph = ${$data};
            $ph =~ s/\D//gxms;
            if ( not length($ph) == 10 ) {
                Note::Check::fail('Invalid phone number');
            }
            return TRUE;
        },
    ),
);

sub cmd_fund {
    my ( $self, $data, $args ) = @_;
    ::_log( 'Fund:', $data );
    my $rec = {};
    my @err = ();
    foreach my $k (qw/first_name last_name address address2 city email/) {
        if ( defined $data->{$k} ) {
            $data->{$k} =~ s/^\s+//gxms;
            $data->{$k} =~ s/\s+$//gxms;
        }
    }
    my %label = (
        'first_name' => 'First Name',
        'last_name'  => 'Last Name',
        'phone'      => 'Phone',
        'address'    => 'Address',
        'address2'   => 'Address (2)',
        'city'       => 'City',
        'state'      => 'State',
        'zip'        => 'Zip',
    );
    foreach my $k ( sort keys %payment_check ) {
        my $data_subset = $data->{$k};
        my $cr          = $payment_check{$k};
        if ( $cr->valid( \$data_subset ) ) {
            $rec->{$k} = $data_subset;
        }
        else {
            my $tm = $label{$k};
            if ( length $data_subset ) {
                push @err, $tm . ': ' . $cr->error();
            }
            elsif ( $k ne 'address2' ) {
                push @err, $tm . ': Required';
            }
        }
    }
    if ( exists $rec->{'phone'} ) {
        $rec->{'phone'} =~ s/\D//gxms;
    }
    my $user    = $self->user();
    my $user_id = $user->id();
    my $pmt     = Note::Payment->new( $user_id, );
    my $carderr = q{};
    if ( not $data->{'cc_cvv2'} =~ /^\d{3,4}$/xms ) {
        push @err, 'Security Code: Required';
    }
    my $num = $data->{'cc_num'};
    $num =~ s/\D//gxms;
    my $cardok = $pmt->card_check(
        'num'   => $num,
        'expy'  => $data->{'cc_expy'},
        'expm'  => $data->{'cc_expm'},
        'type'  => $data->{'cc_type'},
        'error' => \$carderr,
    );

    if ($carderr) {
        push @err, 'Credit Card: ' . $carderr;
    }
    if ( scalar @err ) {
        $self->value()->{'data'} = $rec;
        $self->value()->{'error'} = join '</br>', @err;
        return;
    }
    if ($cardok) {

        my $cid = $pmt->card_add(
            'num'        => $num,
            'expy'       => $data->{'cc_expy'},
            'expm'       => $data->{'cc_expm'},
            'type'       => $data->{'cc_type'},
            'cvv2'       => $data->{'cc_cvv2'},
            'first_name' => $rec->{'first_name'},
            'last_name'  => $rec->{'last_name'},
            'address'    => $rec->{'address'},
            'address2'   => $rec->{'address2'},
            'city'       => $rec->{'city'},
            'state'      => $rec->{'state'},
            'zip'        => $rec->{'zip'},
        );

        my $act = ( has_account( $user_id, ) ) ? Note::Account->new( $user_id, ) : create_account( $user_id, );

        my $order_row = 'Note::Row::find_insert'->( ring_order => { user_id => $user_id, transaction_id => undef, }, );

        my $order_id = $order_row->id();

        if ( defined $order_id ) {

            my $hashtags = sqltable('ring_cart')->get(
                select => [
                    qw{

                        ring_cart.coupon_id
                        ring_cart.hashtag_id
                        ring_cart.id
                        ring_coupon.amount
                        ring_coupon.code
                        ring_hashtag.hashtag

                        },
                ],
                join_left => [

                    [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
                    [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
                ],
                where => [ { 'ring_cart.user_id' => $user_id, } => and => { 'ring_cart.transaction_id' => undef, }, ],
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

            if ( $total > 0 ) {

                my $attempt_id = $pmt->card_payment(
                    processor => 'paypal',
                    card_id   => $cid,
                    nofork    => TRUE,
                    amount    => $total,
                    ip        => $self->env()->{'REMOTE_ADDR'},
                    callback  => sub {
                        ::_log( "New Balance: \$${ \$act->balance() }", );
                    },
                );

                if ( defined $attempt_id ) {

                    my $attempt = 'Note::Row'->new( payment_attempt => $attempt_id, );

                    if ( $attempt->data('accepted') == 1 ) {

                        my $hashtags = sqltable('ring_cart')->get(
                            select => [
                                qw{

                                    ring_cart.coupon_id
                                    ring_cart.hashtag_id
                                    ring_cart.id
                                    ring_coupon.amount
                                    ring_coupon.code
                                    ring_hashtag.hashtag

                                    },
                            ],
                            join_left => [

                                [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
                                [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
                            ],
                            where => [ { 'ring_cart.user_id' => $user_id, } => and => { 'ring_cart.transaction_id' => undef, }, ],
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

                                my $coupon_row = 'Note::Row'->new( ring_coupon => { id => $coupon_id, }, );

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

                        my $transaction_id = transaction(
                            acct_dst => ( has_account( $user_id, ) ) ? 'Note::Account'->new( $user_id, ) : create_account( $user_id, ),
                            acct_src => account_id( 'payment_paypal', ),
                            amount   => $total,
                            tx_type  => tx_type_id( 'payment_paypal', ),
                            user_id  => $user_id,
                        );

                        $order_row->update( { transaction_id => $transaction_id, }, );

                    }

                }

                my $session = $self->session();

                $session->{'payment_attempt'} = $attempt_id;

                $self->session_write();

                return $self->redirect( $self->url( path => 'u', ), );
            }
        }
    }
}

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

        my $username = $config->{paypal_clientid};
        my $password = $config->{paypal_secret};
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

            # $dbh->{AutoCommit} = FALSE;    # enable transactions, if possible

            try {

                my $order_row = 'Note::Row::find_insert'->( ring_order => { user_id => $user_id, transaction_id => undef, }, );

                my $order_id = $order_row->id();

                if ( defined $order_id ) {

                    my $order_total = $order_row->data('total');

                    my $hashtags = sqltable('ring_cart')->get(
                        select => [
                            qw{

                                ring_cart.coupon_id
                                ring_cart.hashtag_id
                                ring_cart.id
                                ring_coupon.amount
                                ring_coupon.code
                                ring_hashtag.hashtag

                                },
                        ],
                        join_left => [

                            [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
                            [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
                        ],
                        where => [ { 'ring_cart.user_id' => $user_id, } => and => { 'ring_cart.transaction_id' => undef, }, ],
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

                            my $coupon_row = 'Note::Row'->new( ring_coupon => { id => $coupon_id, }, );

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

                                # $dbh->commit;

                                # $dbh->{AutoCommit} = $auto_commit;

                                return $self->redirect( $self->url( path => 'u', ), );

                            }
                            else {

                                # try { $dbh->rollback };

                            }

                        }

                    }
                    else {

                        # try { $dbh->rollback };

                    }

                }
            }
            catch {

                my $error = $ARG;

                ::log( $error, );

                # try { $dbh->rollback };

                return undef;
            };

        }

    }

    my $total = 0;

    my $hashtags = sqltable('ring_cart')->get(
        select => [ qw{ ring_cart.hashtag_id ring_cart.coupon_id ring_hashtag.hashtag ring_coupon.code ring_coupon.amount }, ],
        table  => ring_cart => join_left => [

            [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
            [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
        ],
        where => [ { 'ring_cart.user_id' => $user_id, } => and => { 'ring_cart.transaction_id' => undef, }, ],
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

    $total = sprintf '%.2f', $total;

    my $content = $self->content();

    $content->{payment} = $self->show_payment_form();
    $content->{cartX}   = $hashtags;
    $content->{total}   = $total;

    return $self->SUPER::load( $param, );
}

sub search {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my ( $tag, )         = ( lc( $form_data->{hashtag} ) =~ m{ ( [\s\w\#\,\-]+ ) }xms, );
    my ( $category_id, ) = ( $form_data->{category_id} // q{} =~ m{ \A ( \d+ ) \z }xms, );
    my ( $ringpage_id, ) = ( $form_data->{ringpage_id} // q{} =~ m{ \A ( \d+ ) \z }xms );
    my ( $target, )      = ( $form_data->{target} // q{}, );

    if ( not defined $category_id ) {

        my $category = 'Note::Row::find_insert'->( ring_category => { category => '(None)', }, );

        $category_id = $category->id();

    }

    if ( not defined $tag ) {

        $self->form()->{hashtag} = $form_data->{hashtag};
        $self->value()->{error}  = 'Invalid input.';

        return;

    }

    $tag =~ s{ [_\#\,\-]+ }{ }gxms;
    $tag =~ s{$RE{ws}{crop}}{}gxms;
    $tag =~ s{ \s+ }{_}gxms;

    ( $tag, ) = ( $tag =~ m{ \A ( \w{1,139} ) \z }xms, );

    if ( not defined $tag ) {

        $self->form()->{hashtag} = $form_data->{hashtag};
        $self->value()->{error}  = 'Invalid input.';

        return;

    }
    else {

        $self->form()->{hashtag} = $tag;

    }

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

                my $cart = 'Note::Row::insert'->(
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

sub remove {
    my ( $self, $form_data, $args, ) = @_;

    my $hashtag_model = 'Ring::Model::Hashtag'->new();

    for my $hashtag_id ( $self->request()->parameters()->get_all( "d${ \$self->cmdnum() }-hashtag_id", ) ) {

        if ($hashtag_model->delete(
                user_id => $self->user()->id(),
                id      => $hashtag_id,
            )
            )
        {

            my $cart_row = 'Note::Row'->new(
                ring_cart => {
                    hashtag_id => $hashtag_id,
                    user_id    => $self->user()->id(),
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

    my ( $page, ) = ( ( $self->form()->{page} // 1 ) =~ m{ \A ( \d+ ) \z }xms, );

    my $query = {

        defined $page ? ( page => $page, ) : (),

    };

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => $query, ), );
}

sub apply_coupon_code {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my ( $coupon_code, ) = ( $form_data->{coupon_code} =~ m{ \A ( [[:alpha:]]{4} [[:digit:]]{4} ) \z }xms, );

    my $coupon_row = 'Note::Row'->new(
        ring_coupon => {
            code           => $coupon_code,
            transaction_id => undef,
            user_id        => undef,
        },
    );

    my $coupon_id = $coupon_row->id();

    if ( defined $coupon_id ) {

        try {

            my $cart = 'Note::Row::insert'->(
                ring_cart => {
                    coupon_id => $coupon_id,
                    user_id   => $user_id,
                },
            );

        };

    }

    return $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );
}

sub payment {
    my ( $self, $form_data, $args, ) = @_;

    my $_session = $self->_session();

    my $dbh = $_session->database()->handle()->_dbh();

    my $auto_commit = $dbh->{AutoCommit};

    # $dbh->{AutoCommit} = FALSE;    # enable transactions, if possible

    try {

        my $order_row = 'Note::Row::find_insert'->( ring_order => { user_id => $self->user()->id(), transaction_id => undef, }, );

        my $order_id = $order_row->id();

        if ( defined $order_id ) {

            my $hashtags = sqltable('ring_cart')->get(
                select => [ qw{ ring_cart.id ring_cart.hashtag_id ring_cart.coupon_id ring_hashtag.hashtag ring_coupon.code ring_coupon.amount }, ],
                table  => ring_cart => join_left => [

                    [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
                    [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
                ],
                where => [ { 'ring_cart.user_id' => $self->user()->id(), } => and => { 'ring_cart.transaction_id' => undef, }, ],
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

            if ( $total > 0 ) {

                my $config = $main::note_config->config();

                my $username = $config->{paypal_clientid};
                my $password = $config->{paypal_secret};
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

                        # $dbh->commit;

                        # $dbh->{AutoCommit} = $auto_commit;

                        return $self->redirect( $redirect, );

                    }

                }

            }
            else {

                my $hashtags = sqltable('ring_cart')->get(
                    select => [ qw{ ring_cart.id ring_cart.hashtag_id ring_cart.coupon_id ring_hashtag.hashtag ring_coupon.code ring_coupon.amount }, ],
                    table  => ring_cart => join_left => [

                        [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ],
                        [ ring_coupon  => 'ring_coupon.id = ring_cart.coupon_id', ],
                    ],
                    where => [ { 'ring_cart.user_id' => $self->user()->id(), } => and => { 'ring_cart.transaction_id' => undef, }, ],
                );

                for my $hashtag ( @{$hashtags} ) {

                    my $amount = $hashtag->{amount};

                    my $hashtag_id = $hashtag->{hashtag_id};
                    my $coupon_id  = $hashtag->{coupon_id};

                    if ( defined $hashtag_id ) {

                        $amount //= 99.99;

                        my $account_destination = account_id( 'revenue_ringmail', );
                        my $account_source      = has_account( $self->user()->id(), ) ? 'Note::Account'->new( $self->user()->id(), ) : create_account( $self->user()->id(), );
                        my $tx_type_id          = tx_type_id( 'purchase_hashtag', );

                        my $transaction_id = transaction(
                            acct_dst => $account_destination,
                            acct_src => $account_source,
                            amount   => $amount,
                            tx_type  => $tx_type_id,
                            user_id  => $self->user()->id(),
                        );

                        my $cart_row = 'Note::Row'->new(
                            ring_cart => {
                                hashtag_id => $hashtag_id,
                                user_id    => $self->user()->id(),
                            },
                        );

                        my $hashtag_row = 'Note::Row'->new(
                            ring_hashtag => {
                                id      => $hashtag_id,
                                user_id => $self->user()->id(),
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

                    if ( defined $coupon_id ) {

                        my $account_source      = account_id('coupon_source');
                        my $account_destination = account_id('coupon_destination');
                        my $tx_type_id          = tx_type_id('coupon');

                        my $transaction_id = transaction(
                            acct_dst => $account_destination,
                            acct_src => $account_source,
                            amount   => $amount,
                            tx_type  => $tx_type_id,
                            user_id  => $self->user()->id(),
                        );

                        my $cart_row = 'Note::Row'->new(
                            ring_cart => {
                                coupon_id => $coupon_id,
                                user_id   => $self->user()->id(),
                            },
                        );

                        my $coupon_row = 'Note::Row'->new( ring_coupon => { id => $coupon_id, }, );

                        if ( defined $cart_row->id() and defined $coupon_row->id() ) {
                            $cart_row->update(
                                {

                                    transaction_id => $transaction_id,

                                },
                            );

                            $coupon_row->update(
                                {

                                    transaction_id => $transaction_id,
                                    user_id        => $self->user()->id(),

                                },
                            );
                        }

                    }

                }

                # $dbh->commit;

                # $dbh->{AutoCommit} = $auto_commit;

                return $self->redirect( $self->url( path => 'u', ), );

            }

        }

    }
    catch {

        my $error = $ARG;

        ::log( $error, );

        # try { $dbh->rollback };

        return undef;
    };

    return;
}

1;
