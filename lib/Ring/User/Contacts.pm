package Ring::User::Contacts;
use strict;
use warnings;

use vars qw();

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
	my $item = new Ring::Item();
	my $devrc = $item->item(
		'type' => 'device',
		'device_uuid' => $param->{'device_uuid'},
		'user_id' => $uid,
	);
	my $sr = new Note::Row('ring_user_contact_sync' => {
		'user_id' => $uid,
		'device_id' => $devrc->id(),
	})
	if ($sr->id())
	{
		return $sr->data('ts_latest');
	}
	else
	{
		return '';
	}
}

sub load_contacts
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user_id();
	my $item = new Ring::Item();
	my $devrc = $item->item(
		'type' => 'device',
		'device_uuid' => $param->{'device_uuid'},
		'user_id' => $uid,
	);
	my $cts = $param->{'contacts'};
	foreach my $r (@$cts)
	{
		$obj->add_contact(
			'device_id' => $devrc->id(),
			'contact' => $r,
		);
	}
}

sub add_contact
{
	my ($obj, $param) = get_param(@_);
	my $dev = $param->{'device_id'};
	my $ct = $param->{'contact'};
	my $uid = $obj->user_id();
	my $ts = str2time($ct->{'ts'});
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
	$obj->add_contact_emails(
		'contact_id' => $ctrec->{'id'},
		'emails' => $ct->{'em'},
	);
	$obj->add_contact_phones(
		'contact_id' => $ctrec->{'id'},
		'phones' => $ct->{'ph'},
	);
}

sub add_contact_emails
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact_id'};
	my $emails = $param->{'emails'};
	foreach my $em (@$emails)
	{
		Note::Row::find_create('ring_contact_email' => {
			'contact_id' => $ct,
			'email_hash' => $em,
		});
		# match
	}
}

sub add_contact_phones
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact_id'};
	my $phones = $param->{'phones'};
	foreach my $ph (@$phones)
	{
		Note::Row::find_create('ring_contact_phone' => {
			'contact_id' => $ct,
			'phone_hash' => $ph,
		});
		# match
	}
}

1;

