#!/usr/bin/perl
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use strict;
use warnings;

use POSIX 'strftime';
use Try::Tiny;
use Note::Base;

my $ct = sqltable('ring_user')->count();

::log($ct);

transaction(sub {
	Note::Row::create('account_transaction_type' => {
		'name' => 'test_'. strftime("%T", localtime()),
	});
	::log(sqltable('account_transaction_type')->get());
	die('Don\'t do it!');
});

