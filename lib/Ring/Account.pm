package Ring::Account;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Email::Valid;
use POSIX 'strftime';
use String::Random;
use MIME::Lite;

use Note::Param;
use Note::Row;
use Note::Check;
use Note::XML 'xml';
use Ring::Item;
use Ring::User;

no warnings qw(uninitialized);

has 'user' => (
	'is' => 'rw',
	'isa' => 'Ring::User',
);

sub add_card
{
	my ($obj, $param) = get_param(@_);
}

sub attempt_payment
{
	my ($obj, $param) = get_param(@_);
}

sub add_monthly
{
}

1;

