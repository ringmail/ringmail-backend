package Page::ring::setup::cart;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::Account qw(account_id transaction tx_type_id);

use Note::XML 'xml';
use Note::Param;
use Note::Account 'has_account', 'create_account';
use Note::Payment;
use Note::Check;
use Note::Locale;
use Note::SQL::Table 'sqltable';

use Ring::User;

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
        'chars_empty' => 1,
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
            return 1;
        },
    ),
);

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param(@args);

    my $form = $self->form();

    my $content = $self->content();
    my $user    = $self->user();
    my $account = Note::Account->new( $user->id() );

    my $hashtags = sqltable('ring_cart')->get(
        select => [ qw{ rh.hashtag rh.id rc.hashtag_id }, ],
        table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
        join   => 'rh.id = rc.hashtag_id',
        where  => [
            {   'rc.user_id' => $user->id(),
                'rh.user_id' => $user->id(),
            } => and => { 'rc.transaction_id' => undef, },
        ],
    );

    $content->{balance} = $account->balance();
    $content->{payment} = $self->show_payment_form();
    $content->{total}   = 1.99 * scalar @{$hashtags};

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
    my $pmt     = Note::Payment->new( $user->id(), );
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

        my $act = ( has_account( $user->id(), ) ) ? Note::Account->new( $user->id(), ) : create_account( $user->id(), );

        my $hashtags = sqltable('ring_cart')->get(
            select => [ qw{ rh.hashtag rh.id rc.hashtag_id }, ],
            table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
            join   => 'rh.id = rc.hashtag_id',
            where  => [
                {   'rc.user_id' => $user->id(),
                    'rh.user_id' => $user->id(),
                } => and => { 'rc.transaction_id' => undef, },
            ],
        );

        my $total = 1.99 * scalar @{$hashtags};

        my $attempt = $pmt->card_payment(
            'processor' => 'paypal',
            'card_id'   => $cid,
            'nofork'    => 1,
            'amount'    => $total,
            'ip'        => $self->env()->{'REMOTE_ADDR'},
            'callback'  => sub {
                ::_log( 'New Balance:', $act->balance() );
            },
        );

        for my $hashtag ( @{$hashtags} ) {

            my $src = Note::Account->new( $user->id(), );
            my $dst = account_id('revenue_ringmail');

            my $transaction_id = transaction(
                acct_dst => $dst,
                acct_src => $src,
                amount   => 1.99,                             # TODO fix
                tx_type  => tx_type_id('purchase_hashtag'),
                user_id  => $user->id(),
            );

            my $cart = Note::Row->new(
                ring_cart => {
                    hashtag_id => $hashtag->{id},
                    user_id    => $user->id(),
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

        my $sd = $self->session();
        $sd->{'payment_attempt'} = $attempt;
        $self->session_write();
        ::_log( 'Attempt:', $attempt );
        return $self->redirect('/u/settings/processing');
    }
}

1;
