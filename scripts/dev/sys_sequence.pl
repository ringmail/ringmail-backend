#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use POSIX 'strftime';
use Digest::SHA 'sha256_hex';
use URI::Escape 'uri_escape';
use Note::Base;

my @tlbs = qw(
	account
	account_name
	account_transaction
	account_transaction_type
	payment
	payment_attempt
	payment_card
	payment_error
	payment_lock
	payment_proc
	ring_category
	ring_did
	ring_domain
	ring_domain_user
	ring_email
	ring_phone
	ring_target
	ring_user
	ring_user_domain
	ring_user_email
	ring_verify_domain
	ring_verify_email
);

my $st = sqltable('note_sequence');
foreach my $i (@tlbs)
{
	my $qry = "select a.id from `$i` a where not exists (select * from note_sequence n where n.id=a.id);";
	my $res = sqltable($i)->database()->query($qry);
	foreach my $r (@$res)
	{
		$st->set(
			'insert' => {
				'id' => $r->[0],
				'timestamp' => strftime("%F %T", localtime()),
			},
		);
	}
	::log($i. ': '. scalar(@$res));
}

