package Ring::App;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;

use Note::Param;
use Note::App;
use base qw(Note::App);

no warnings qw(uninitialized);

# default, directory lookup dispatcher
sub dispatch
{
	my ($obj, $param) = get_param(@_);
	return $obj->SUPER::dispatch($param);
}

1;

