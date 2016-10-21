package Page::ring::setup::admin::coupons;

use Math::Random::Secure 'rand';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Readonly;
use Regexp::Common 'number';
use String::Random 'random_regex';

our $VERSION = 1;

extends 'Page::ring::user';

Readonly my $PAGE_SIZE => 10;

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $where_clause = {

        not( defined $self->form()->{redeemed} and $self->form()->{redeemed} == 1 ) ? ( transaction_id => undef, ) : (),
        not( defined $self->form()->{sent}     and $self->form()->{sent} == 1 )     ? ( sent           => 0, )     : (),

    };

    $self->content()->{count} = sqltable('ring_coupon')->count( $where_clause, );

    my ( $page, ) = ( $self->form()->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $page_size = $self->app()->config()->{page_size} // $PAGE_SIZE;

    $self->content()->{coupons} = sqltable('ring_coupon')->get(
        select => [
            qw{

                ring_coupon.amount
                ring_coupon.code
                ring_coupon.id
                ring_coupon.sent
                ring_coupon.transaction_id

                },
        ],
        where => $where_clause,
        order => qq{ring_coupon.id DESC LIMIT ${ \ do { ( $page - 1 ) * $page_size } }, $page_size},
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

        } while ( $coupon->count( code => $random_string, ) > 0 );    ## no critic ( Perl::Critic::Policy::ControlStructures::ProhibitPostfixControls )

        my $coupon_row = 'Note::Row::insert'->( ring_coupon => { code => $random_string, amount => $amount, }, );

        return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), ), );
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
