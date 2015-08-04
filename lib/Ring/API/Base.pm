package Ring::API::Base;
use strict;
use warnings;

use vars qw();

use Scalar::Util 'blessed', 'reftype';
use Carp::Always;

use Ring::API;

use Note::Param;

no warnings qw(uninitialized);

sub new
{
	my ($class) = @_;
	my $obj = {};
	bless $obj, $class;
	return $obj;
}

sub subcmd
{
	my ($obj, $param) = get_param(@_);
	my $path = $param->{'path'};
	my $data = $param->{'data'};
	my $cmd = shift @$path;
	unless ($obj->can($cmd))
	{
		die(qq|Undefined method: '$cmd' for |. __PACKAGE__);
	}
	return $obj->$cmd({
		'path' => $path,
		'data' => $data,
	});
}

sub cmd
{
	my $obj = shift;
	return Ring::API->cmd(@_);
}

1;

