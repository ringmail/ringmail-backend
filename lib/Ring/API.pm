package Ring::API;
use strict;
use warnings;

use vars qw(%commands);

use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Carp::Always;

use Note::Param;
use Note::Log;

use Ring::API::User;
use Ring::API::Route;

no warnings qw(uninitialized);

sub cmd
{
	my ($class, $param) = get_param(@_);
	my $path = [@{$param->{'path'}}]; # copy to preserve for error
	my $data = {%{$param->{'data'}}}; # copy
	unless (ref($path) && reftype($path) eq 'ARRAY')
	{
		die('Invalid path for command');
	}
	unless (ref($data) && reftype($data) eq 'HASH')
	{
		die('Invalid data for command');
	}
	my $cmd = shift @$path;
	unless (exists $commands{$cmd})
	{
		die(qq|Unknown command: '$cmd'|);
	}
	my $result = {};
	eval {
		local $SIG{__DIE__} = \&Carp::Always::_die;
		local $SIG{__WARN__} = \&Carp::Always::_warn;
		$result = $commands{$cmd}->subcmd(
			'path' => $path,
			'data' => $data,
		);
	};
	if ($@)
	{
		my $err = $@;
		$result->{'ok'} = 0;
		$result->{'errors'} = [
			'perl',
			"An error occurred in command: '$cmd'",
			{
				'path' => $param->{'path'},
				'data' => $param->{'data'},
				'error' => $err,
			}
		];
	}
	return $result;
}

END: {
	our %commands = (
		'user' => new Ring::API::User(),
		'route' => new Ring::API::Route(),
		#'login' => new Ring::API::Login(),
		#'directory' => new Ring::API::Directory(),
	);
}

1;

