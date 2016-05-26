package Ring::Model::Category;

use strict;
use warnings;

use Moose;

use Note::Param;
use Note::SQL::Table 'sqltable';

sub get_categories {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_category')->get( 'select' => [ qw{ id category }, ], );
    return $q;
}

1;
