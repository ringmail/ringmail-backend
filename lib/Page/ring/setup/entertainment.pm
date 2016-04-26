package Page::ring::setup::entertainment;

use strict;
use warnings;

use Moose;

use Note::Param;
use Ring::Model::RingPage;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    my $ringpage = Ring::Model::RingPage->new();

    $obj->content()->{ringpage} = $ringpage->retrieve( user_id => $obj->user()->id(), id => $param->{form}->{ringpage_id}, );

    return $obj->$next( $param, );
};

1;
