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

my $testact1 = Note::Account::account_id("payment_test");
my $testact2 = Note::Account::account_id("revenue_test");
my $act = new Note::Account($q);

my $txid = Note::Account::transaction(
	'acct_src' => $testact1,
	'acct_dst' => $act,
	'amount' => 5.00,
	'entity' => '456',
	'tx_type' => 'payment_test',
);
::log("Transaction: $txid");
::log("Payment Account: ". $testact1->balance());
::log("User($q) Account: ". $act->balance());

$txid = Note::Account::transaction(
	'acct_src' => $act,
	'acct_dst' => $testact2,
	'amount' => 7.00,
	'entity' => '789',
	'tx_type' => 'payment_test',
);

::log("Transaction: $txid");
::log("Revenue Account: ". $testact2->balance());
::log("User($q) Account: ". $act->balance());

