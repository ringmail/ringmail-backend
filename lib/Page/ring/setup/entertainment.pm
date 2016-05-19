package Page::ring::setup::entertainment;

use strict;
use warnings;

use Moose;

use Note::Param;
use Note::SQL::Table 'sqltable';

use Ring::Model::RingPage;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    my $ringpage_id = $param->{form}->{ringpage_id};

    my $ringpage_model = Ring::Model::RingPage->new();

    my $ringpage = $ringpage_model->retrieve( id => $ringpage_id, );

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ 'button', 'uri', ],
        where => { ringpage_id => $ringpage_id, },
    );

    $obj->content()->{ringpage} = $ringpage;
    $obj->content()->{ringpage}->{buttons} = $buttons;

    return $obj->$next( $param, );
};

1;
