package Ring::User::Contacts;
use strict;
use warnings;

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use Date::Parse 'str2time';

use Note::SQL::Table 'sqltable';
use Note::Param;

no warnings qw(uninitialized);

has 'user_id' => (
	'is' => 'rw',
	'isa' => 'Int',
	'required' => 1,
);

sub sync_timestamp
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	my $sr = new Note::Row('ring_user_contact_sync' => {
		'user_id' => $uid,
		'device_id' => $param->{'device_id'},
	});
	if ($sr->id())
	{
		return $sr->data('ts_latest'). 'Z';
	}
	else
	{
		return '';
	}
}

sub get_contacts_count
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	return sqltable('ring_contact')->count(
		'user_id' => $uid,
		'device_id' => $param->{'device_id'},
	);
}

sub get_matched_contacts
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	my $q = sqltable('ring_contact')->get(
		'array' => 1,
		'select' => ['internal_id'],
		'where' => [
			{
				'user_id' => $uid,
				'device_id' => $param->{'device_id'},
				'matched_user_id' => ['is not', undef],
			},
			'and',
			{
				'matched_user_id' => ['!=', $uid],
			},
		],
	);
	#::log("Matched For:$uid", $q);
	return [map {$_->[0]} @$q];
}

sub get_device_matches
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	my @res = ();
	my $q = sqltable('ring_contact')->get(
		'array' => 1,
		'table' => ['ring_contact c, ring_contact_email e'],
		'select' => ['e.email_hash'],
		'join' => 'c.id=e.contact_id',
		'where' => [
			{
				'c.user_id' => $uid,
				'c.device_id' => $param->{'device_id'},
				'c.matched_user_id' => ['is not', undef],
				'e.matched_user_id' => ['is not', undef],
			},
			'and',
			{
				'c.matched_user_id' => ['!=', $uid],
				'e.matched_user_id' => ['!=', $uid],
			},
		],
	);
	push @res, map {$_->[0]} @$q;
	$q = sqltable('ring_contact')->get(
		'array' => 1,
		'table' => ['ring_contact c, ring_contact_phone p'],
		'select' => ['p.phone_hash'],
		'join' => 'c.id=p.contact_id',
		'where' => [
			{
				'c.user_id' => $uid,
				'c.device_id' => $param->{'device_id'},
				'c.matched_user_id' => ['is not', undef],
				'p.matched_user_id' => ['is not', undef],
			},
			'and',
			{
				'c.matched_user_id' => ['!=', $uid],
				'p.matched_user_id' => ['!=', $uid],
			},
		],
	);
	push @res, map {$_->[0]} @$q;
	return \@res;
}

sub load_contacts
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	my %current = ();
	if ($param->{'purge'})
	{
		my $q = sqltable('ring_contact')->get(
			'array' => 1,
			'select' => ['id', 'internal_id'],
			'where' => {
				'device_id' => $param->{'device_id'},
				'user_id' => $uid,
			},
		);
		%current = map {$_->[1] => $_->[0]} @$q;
	}
	my $cts = $param->{'contacts'};
	my $maxts = undef;
	foreach my $r (@$cts)
	{
		if (exists $current{$r->{'id'}})
		{
			delete $current{$r->{'id'}};
		}
		$obj->add_contact(
			'device_id' => $param->{'device_id'},
			'contact' => $r,
			'max_ts_ref' => \$maxts,
			'purge' => $param->{'purge'},
		);
	}
	if (defined $maxts)
	{
		my $src = Note::Row::find_create('ring_user_contact_sync' => {
			'user_id' => $uid,
			'device_id' => $param->{'device_id'},
		});
		$src->update({
			'ts_latest' => strftime("%F %T", gmtime($maxts)),
		});
	}
	if ($param->{'purge'})
	{
		my @ks = keys %current;
		foreach my $k (@ks)
		{
			my $cid = $current{$k};
			$obj->delete_contact(
				'contact_id' => $cid,
			);
		}
	}
}

sub add_contact
{
	my ($obj, $param) = get_param(@_);
	my $dev = $param->{'device_id'};
	my $ct = $param->{'contact'};
	my $maxtsref = $param->{'max_ts_ref'};
	my $uid = $obj->user_id();
	my $ts = str2time($ct->{'ts'});
	if (defined ${$maxtsref})
	{
		if (${$maxtsref} < $ts)
		{
			${$maxtsref} = $ts;
		}
	}
	else
	{
		${$maxtsref} = $ts;
	}
	my $ctrec = Note::Row::find_create('ring_contact' => {
		'user_id' => $uid,
		'device_id' => $dev,
		'internal_id' => $ct->{'id'},
	}, {
		'ts_created' => strftime("%F %T", gmtime($ts)),
	});
	$ctrec->update({
		'first_name' => $ct->{'fn'},
		'last_name' => $ct->{'ln'},
		'organization' => $ct->{'co'},
		'ts_updated' => strftime("%F %T", gmtime($ts)),
	});
	my $match = $obj->add_contact_emails(
		'contact_id' => $ctrec->{'id'},
		'emails' => $ct->{'em'},
		'purge' => $param->{'purge'},
	);
	$match ||= $obj->add_contact_phones(
		'contact_id' => $ctrec->{'id'},
		'phones' => $ct->{'ph'},
		'purge' => $param->{'purge'},
	);
	$ctrec->update({
		'matched_user_id' => $match,
	});
}

sub add_contact_emails
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact_id'};
	my %current = ();
	if ($param->{'purge'})
	{
		my $q = sqltable('ring_contact_email')->get(
			'array' => 1,
			'select' => ['email_hash', 'id'],
			'where' => {
				'contact_id' => $ct,
			},
		);
		%current = map {$_->[0] => $_->[1]} @$q;
	}
	my $emails = $param->{'emails'};
	my $match = undef;
	foreach my $em (@$emails)
	{
		if (exists $current{$em})
		{
			delete $current{$em};
		}
		my $item = Note::Row::find_create('ring_contact_email' => {
			'contact_id' => $ct,
			'email_hash' => $em,
		});
		# find match
		my $matches = sqltable('ring_user_email')->get(
			'array' => 1,
			'select' => [
				'ue.user_id',
			],
			'table' => 'ring_email e, ring_user_email ue',
			'join' => [
				'e.id=ue.email_id',
			],
			'where' => {
				'e.email_hash' => $em,
				'ue.primary_email' => 1,
			},
		);
		if (scalar @$matches)
		{
			# match :)
			$match ||= $matches->[0]->[0]; # only take the first email that matches
			$item->update({
				'matched_user_id' => $match,
			});
		}
	}
	if ($param->{'purge'})
	{
		my @ks = keys %current;
		foreach my $k (@ks)
		{
			my $rid = $current{$k};
#			my $prevmatch = sqltable('ring_contact_email')->get(
#				'array' => 1,
#				'select' => ['matched_user_id'],
#				'where' => {
#					'id' => $rid,
#				},
#			)->[0]->[0];
#			if (defined $prevmatch) # only remove from main contact if its the same as this entity (another remaining item may add a match back to the main contact)
#			{
#				sqltable('ring_contact')->set(
#					'update' => {
#						'matched_user_id' => undef,
#					},
#					'where' => {
#						'id' => $ct,
#						'matched_user_id' => $prevmatch,
#					},
#				);
#			}
			sqltable('ring_contact_email')->delete(
				'where' => {'id' => $rid},
			);
		}
	}
	return $match;
}

sub add_contact_phones
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact_id'};
	my $phones = $param->{'phones'};
	my %current = ();
	if ($param->{'purge'})
	{
		my $q = sqltable('ring_contact_phone')->get(
			'array' => 1,
			'select' => ['phone_hash', 'id'],
			'where' => {
				'contact_id' => $ct,
			},
		);
		%current = map {$_->[0] => $_->[1]} @$q;
	}
	my $match = undef;
	foreach my $ph (@$phones)
	{
		if (exists $current{$ph})
		{
			delete $current{$ph};
		}
		my $item = Note::Row::find_create('ring_contact_phone' => {
			'contact_id' => $ct,
			'phone_hash' => $ph,
		});
		my $matches = sqltable('ring_user_did')->get(
			'array' => 1,
			'select' => [
				'ud.user_id',
			],
			'table' => 'ring_did d, ring_user_did ud',
			'join' => [
				'd.id=ud.did_id',
			],
			'where' => {
				'd.did_hash' => $ph,
			},
		);
		if (scalar @$matches)
		{
			# match :)
			$match ||= $matches->[0]->[0]; # only take the first phone that matches
			$item->update({
				'matched_user_id' => $match,
			});
		}
	}
	if ($param->{'purge'})
	{
		my @ks = keys %current;
		foreach my $k (@ks)
		{
			my $rid = $current{$k};
			sqltable('ring_contact_phone')->delete(
				'where' => {'id' => $rid},
			);
		}
	}
	if (defined $match)
	{
		# only update main contact if not already set
		sqltable('ring_contact')->set(
			'update' => {
				'matched_user_id' => $match,
			},
			'where' => {
				'id' => $ct,
				'matched_user_id' => ['is', undef],
			},
		);
	}
	return $match;
}

sub delete_contact
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact_id'};
	sqltable('ring_contact_phone')->delete(
		'where' => {'contact_id' => $ct},
	);
	sqltable('ring_contact_email')->delete(
		'where' => {'contact_id' => $ct},
	);
	sqltable('ring_contact')->delete(
		'where' => {'id' => $ct},
	);
}

1;

