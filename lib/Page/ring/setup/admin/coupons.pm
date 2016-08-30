package Page::ring::setup::admin::coupons;

use Math::Random::Secure 'rand';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'number';
use String::Random 'random_regex';

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();
    my $form    = $self->form();

    my $where_clause;

    if ( not( defined $form->{redeemed} and $form->{redeemed} == 1 ) ) {

        $where_clause = {

            transaction_id => undef,

        };

    }

    my ( $page, ) = ( $form->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $offset = ( $page * 10 ) - 10;

    my $count = sqltable('ring_coupon')->count();

    my $coupons = sqltable('ring_coupon')->get(
        select => [
            qw{

                amount
                code
                id
                sent
                transaction_id

                },
        ],
        where => $where_clause,
        order => qq{code LIMIT $offset, 10},
    );

    $content->{count}   = $count;
    $content->{coupons} = $coupons;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args, ) = @_;

    my $form  = $self->form();
    my $value = $self->value();

    my $currency = $RE{num}{decimal}{ -places => '0,2' }{ -sign => q{} };

    my ( $amount, ) = ( $form_data->{amount} =~ m{ \A ( $currency ) \z }xms, );

    if ( defined $amount and $amount > 0 ) {

        my $coupon = 'Note::Row::table'->('ring_coupon');

        my $random_string;

        do {

            $random_string = random_regex '[A-Z]{4}[0-9]{4}';

        } while ( $coupon->count( code => $random_string, ) > 0 );

        my $coupon_row = 'Note::Row::create'->( ring_coupon => { code => $random_string, amount => $amount, }, );

        my $redeemed = ( defined $form->{redeemed} and $form->{redeemed} == 1 ) ? $form->{redeemed} : undef;

        return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => defined $redeemed ? { redeemed => $redeemed, } : undef, ), );
    }
    else {

        $form->{amount} = $form_data->{amount};
        $value->{error} = 'Amount is invalid.';

    }

    return;
}

sub mark_sent {
    my ( $self, $form_data, $args, ) = @_;

    my $form = $self->form();

    my ( $coupon_id, ) = ( @{$args}, );

    ( $coupon_id, ) = ( $coupon_id =~ m{ \A ( \d+ ) \z }xms, );

    if ( defined $coupon_id and $coupon_id > 0 ) {

        my $coupon_row = 'Note::Row'->new( ring_coupon => $coupon_id, );

        $coupon_row->update( { sent => 1, }, );

    }

    return;
}

1;
