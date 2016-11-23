#!/usr/bin/perl
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use strict;
use warnings;

use Data::Dumper;
use POSIX 'strftime';
use Try::Tiny;
use Note::Base;
use Carp::Always;
use Scalar::Util 'blessed';
use Exception::Class (
	'UserFailure',
);

my $ct = sqltable('ring_user')->count();

::log($ct);

try {
	transaction(sub {
		Note::Row::create('account_transaction_type' => {
			'name' => 'test_'. strftime("%T", localtime()),
		});
		::log(sqltable('account_transaction_type')->get());
		#die('Don\'t do it!');
		UserFailure->throw('error' => 'A big fit!');
	});
	print "Transaction succeeded\n";
} catch {
	my $err = $_;
	if (blessed($err) && $err->isa('UserFailure'))
	{
		$err = 'User Failure: '. $err->error();
	}
	print "It blew up and said '$err'!\n";
} finally {
	if (@_)
	{
		print "Error... bummer!\n";
	}
	else
	{
		print "Everything worked great!\n";
	}
};

print "All Done!\n";
