package Ring::Exceptions;
use strict;
use warnings;

use Exporter 'import';
use Exception::Class (
	'InvalidUserInput',

	'DuplicateData',

	'FatalError',
);

use vars ('@EXPORT_OK');

@EXPORT_OK = (
	'throw_duplicate',
);

sub throw_duplicate
{
	my ($func, $dupmsg) = @_;
	my $rv = undef;
	eval {
		$rv = $func->();
	};
	if ($@)
	{
		my $err = $@;
		if ($err =~ /duplicate/i)
		{
			DuplicateData->throw('message' => $dupmsg);
		}
		else
		{
			FatalError->throw('message' => $err);
		}
	}
	return $rv;
}

1;

