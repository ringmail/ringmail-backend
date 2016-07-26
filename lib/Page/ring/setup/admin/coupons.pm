package Page::ring::setup::admin::coupons;

use Math::Random::Secure 'rand';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use String::Random 'random_regex';

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();

    my $coupons = sqltable('coupon')->get(
        select => [ qw{ code transaction_id }, ],
        table  => [ 'coupon AS c', ],
    );

    $content->{coupons} = $coupons;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args, ) = @_;

    my $coupon = 'Note::Row::table'->('coupon');

    my $random_string;

    do {

        $random_string = random_regex '[A-Z]{4}[0-9]{4}';

    } while ( $coupon->count( code => $random_string, ) > 0 );

    my $coupon_row = 'Note::Row::create'->( coupon => { code => $random_string, }, );

    return $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );
}

1;
