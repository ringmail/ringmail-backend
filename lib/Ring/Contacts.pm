package Ring::Contacts;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';

use Ring::User;

no warnings qw(uninitialized);

has 'user' => (
	'is' => 'rw',
	'isa' => 'Ring::User',
	'required' => 1,
);

sub count_user_contacts
{
	my ($obj) = @_;
	my $q1 = sqltable('ring_contact')->count(
		'user_id' => $obj->user()->id(),
	);
	return $q1;
}

sub query_user_contacts
{
	my ($obj, $param) = get_param(@_);
	my $lim = $param->{'limit'};
	my $offset = $param->{'offset'};
	my $order = 'organization asc, first_name asc, last_name asc';
	if (defined $lim)
	{
		$order .= ' LIMIT '. $lim;
	}
	if (defined $offset)
	{
		$order .= ' OFFSET '. $offset;
	}
	my $q1 = sqltable('ring_contact')->get(
		'hash' => 1,
		'select' => [
			'id',
			'apple_id',
			'first_name',
			'last_name',
			'organization',
		],
		'where' => {
			'user_id' => $obj->user()->id(),
		},
		'order' => $order,
	);
	my $q2;
	my $q3;
	my %emails = ();
	my %phones = ();
	if (scalar @$q1)
	{
		my $ids = join(',', map {$_->{'id'}} @$q1);
		$q2 = sqltable('ring_contact_email')->get(
			'hash' => 1,
			'table' => 'ring_contact_email e, ring_email em',
			'select' => ['e.contact_id', 'em.email'],
			'join' => 'em.id=e.email_id',
			'where' => "e.contact_id in ($ids)",
		);
		$q3 = sqltable('ring_contact_phone')->get(
			'hash' => 1,
			'table' => 'ring_contact_phone e, ring_did d',
			'select' => ['e.contact_id', 'd.did_code', 'd.did_number'],
			'join' => 'd.id=e.did_id',
			'where' => "e.contact_id in ($ids)",
		);
		foreach my $r (@$q2)
		{
			$emails{$r->{'contact_id'}} ||= [];
			push @{$emails{$r->{'contact_id'}}}, $r->{'email'};
		}
		foreach my $r (@$q3)
		{
			$phones{$r->{'contact_id'}} ||= [];
			push @{$phones{$r->{'contact_id'}}}, {
				'did_code' => $r->{'did_code'},
				'did_number' => $r->{'did_number'},
			};
		}
	}
	foreach my $r (@$q1)
	{
		$r->{'email'} = $emails{$r->{'id'}};
		$r->{'phone'} = $phones{$r->{'id'}};
	}
	return $q1;
}

1;

