#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Carp::Always;
use Data::Dumper;
use POSIX 'strftime';
use Note::Base;
use Note::Account;

my $q = sqltable('ring_user')->get(
	'select' => 'id',
	'result' => 1,
	'array' => 1,
	'limit' => 1,
);

my $testact = Note::Account::account_id("payment_test");
my $act = new Note::Account($q);

my $txid = Note::Account::transaction(
	'acct_src' => $testact,
	'acct_dst' => $act,
	'amount' => 10.00,
	'entity' => '123',
	'tx_type' => 'payment_test',
);

::log("Transaction: $txid");
::log("Payment Account: ". $testact->balance());
::log("User($q) Account: ". $act->balance());

