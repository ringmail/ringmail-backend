package Ring::Valid;
use strict;
use warnings;

use Exporter 'import';
use Email::Valid;
use Number::Phone::Country;

use vars ('@EXPORT_OK');

@EXPORT_OK = (qw/
	validate_phone
	validate_email
	split_phone
/);

sub validate_phone
{
	my ($phone) = shift;
	if ($phone =~ /^\+?[1-9]\d{10,14}$/)
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

sub split_phone
{
	my ($phone) = shift;
	my ($iso_cc, $did_code) = Number::Phone::Country::phone2country_and_idd($phone);
	my $ms = "\\+". $did_code;
	my $dm = qr($ms);
	$phone =~ s/^$dm//;
	return ($did_code, $phone);
}

