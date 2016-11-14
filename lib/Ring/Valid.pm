package Ring::Valid;
use strict;
use warnings;

use Exporter 'import';
use Email::Valid;

@EXPORT_OK = (qw/
	validate_phone
	validate_email
/);

sub validate_phone
{
	my ($phone) = shift;
	if ($phone =~ /^\+?\d{6,7}[2-9]\d{3}$/)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub validate_email
{
	my ($email) = shift;
	return Email::Valid->address($email);
}

