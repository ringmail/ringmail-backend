package Ring::Model::Category;

use Moose;
use Note::SQL::Table 'sqltable';

our $VERSION = 1;

sub list {

    my $categories = sqltable('ring_category')->get( select => [ qw{ id category }, ], );

    return $categories;
}

1;
