package Page::ring::setup::cart;

use constant::boolean;
use Moose;
use Note::Account qw{ account_id transaction tx_type_id has_account create_account };
use Note::Check;
use Note::Param;
use Note::Payment;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'whitespace';
use Ring::Model::Hashtag;

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

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param(@args);

    my $content = $self->content();

    $content->{payment} = $self->show_payment_form();

    return $self->SUPER::load( $param, );
}

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

        my $hashtags = sqltable('ring_cart')->get(
            select => [ qw{ rh.hashtag rh.id rc.hashtag_id }, ],
            table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
            join   => 'rh.id = rc.hashtag_id',
            where  => [
                {   'rc.user_id' => $user_id,
                    'rh.user_id' => $user_id,
                } => and => { 'rc.transaction_id' => undef, },
            ],
        );

        my $total = 99.99 * scalar @{$hashtags};

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

                for my $hashtag ( @{$hashtags} ) {

                    my $src = Note::Account->new( $user_id, );
                    my $dst = account_id('revenue_ringmail');

                    my $transaction_id = transaction(
                        acct_dst => $dst,
                        acct_src => $src,
                        amount   => 99.99,                            # TODO fix
                        tx_type  => tx_type_id('purchase_hashtag'),
                        user_id  => $user_id,
                    );

                    my $hashtag_id = $hashtag->{id};

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

        my $session = $self->session();

        $session->{'payment_attempt'} = $attempt_id;

        $self->session_write();

        return $self->redirect('/u/processing');
    }
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

        return $self->redirect('/u/cart');
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

    my $coupon_row = Note::Row->new(
        coupon => {
            code           => $coupon_code,
            transaction_id => undef,
            user_id        => undef,
        },
    );

    if ( defined $coupon_row->id() ) {

        my $account_source      = account_id('coupon_source');
        my $account_destination = account_id('coupon_destination');
        my $tx_type_id          = tx_type_id('coupon');

        my $transaction_id = transaction(
            acct_dst => $account_destination,
            acct_src => $account_source,
            amount   => 99.99,
            tx_type  => $tx_type_id,
            user_id  => $user_id,
        );

        my $hashtags = sqltable('ring_cart')->get(
            select => [ qw{ rh.hashtag rh.id rc.hashtag_id }, ],
            table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
            join   => 'rh.id = rc.hashtag_id',
            where  => [
                {   'rc.user_id' => $user_id,
                    'rh.user_id' => $user_id,
                } => and => { 'rc.transaction_id' => undef, },
            ],
        );

        my ( $hashtag, ) = ( @{$hashtags}, );

        my $hashtag_id = $hashtag->{id};

        my $hashtag_row = Note::Row->new(
            ring_hashtag => {
                id      => $hashtag_id,
                user_id => $user_id,
            },
        );

        if ( defined $hashtag_row->id() ) {

            my $cart_row = Note::Row->new(
                ring_cart => {
                    hashtag_id => $hashtag_id,
                    user_id    => $user_id,
                },
            );

            if ( defined $cart_row->id() ) {

                if ( $cart_row->update( { transaction_id => $transaction_id, }, ) ) {

                    if ( $hashtag_row->update( { paid => TRUE, }, ) ) {

                        $coupon_row->update(
                            {   transaction_id => $transaction_id,
                                user_id        => $user_id,
                            },
                        );
                    }
                }
            }
        }
    }

    return $self->redirect('/u');
}

1;
