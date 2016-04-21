package Page::ring::setup::entertainment;

use strict;
use warnings;

use Moose;

use Note::Param;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    return $obj->$next( $param, );
};

1;
