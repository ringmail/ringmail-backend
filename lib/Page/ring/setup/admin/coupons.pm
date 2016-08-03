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

    my $where_clause = {};

    ::log( $self, $param, );

    my $coupons = sqltable('coupon')->get(
        select => [ qw{ code transaction_id }, ],
        table  => [ 'coupon AS c', ],
        where  => $where_clause,
    );

    $content->{coupons} = $coupons;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args, ) = @_;

    ::log( $self, $form_data, $args, );

    my $form  = $self->form();
    my $value = $self->value();

    my $currency = $RE{num}{decimal}{ -places => '0,2' }{ -sign => q{} };

    my ( $amount, ) = ( $form_data->{amount} =~ m{ \A ( $currency ) \z }xms, );

    if ( defined $amount and $amount > 0 ) {

        my $coupon = 'Note::Row::table'->('coupon');

        my $random_string;

        do {

            $random_string = random_regex '[A-Z]{4}[0-9]{4}';

        } while ( $coupon->count( code => $random_string, ) > 0 );

        my $coupon_row = 'Note::Row::create'->( coupon => { code => $random_string, amount => $amount, }, );

        my $redeemed = ( defined $form->{redeemed} and $form->{redeemed} == 1 ) ? $form->{redeemed} : undef;

        return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => defined $redeemed ? { redeemed => $redeemed, } : undef, ), );
    }
    else {

        $form->{amount} = $form_data->{amount};
        $value->{error} = 'Amount is invalid.';

    }

    return;
}

1;
