package Ring::Model::Category;

use strict;
use warnings;

use Moose;

use Note::SQL::Table 'sqltable';

sub list {

    my $categories = sqltable('ring_category')->get( select => [ qw{ id category }, ], );

    return $categories;

}

1;
