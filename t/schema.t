use strict;
use warnings;
use Test::More tests => 1;
use Carp::Always;
use Note::Schema;

my $ns = new Note::Schema();
isa_ok($ns, 'Note::Schema');

