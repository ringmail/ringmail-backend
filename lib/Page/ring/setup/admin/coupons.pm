package Page::ring::setup::admin::coupons;

use Math::Random::Secure 'rand';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Readonly;
use Regexp::Common 'number';
use String::Random 'random_regex';

extends 'Page::ring::user';

Readonly my $PAGE_SIZE => 10;

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $where_clause = {

        not( defined $self->form()->{redeemed} and $self->form()->{redeemed} == 1 ) ? ( transaction_id => undef, ) : (),

    };

    $self->content()->{count} = sqltable('ring_coupon')->count( $where_clause, );

    my ( $page, ) = ( $self->form()->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $page_size = $main::app_config->{page_size} // $PAGE_SIZE;

    $self->content()->{coupons} = sqltable('ring_coupon')->get(
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
        order => qq{id DESC LIMIT ${ \ do { ( $page - 1 ) * $page_size } }, $page_size},
    );

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
