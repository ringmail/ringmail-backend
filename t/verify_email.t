#!/usr/bin/perl -I/home/note/lib -I/home/note/app/ringmail/lib
use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Carp::Always;
use Data::Dumper;
use Data::Faker 'Internet', 'Name';
use String::Random 'random_regex';
use Scalar::Util 'blessed';
use Try::Tiny;

use Note::Base 'ringmail';
use Note::Test;
use Ring::Register;

no warnings qw(uninitialized);

my $o = new Ring::Register();

my $email = $ENV{'TEST_EMAIL'};
unless (defined($email) && length($email))
{
	print STDERR "TEST_EMAIL environment variable not defined\n";
	exit(1);
}

my $faker = new Data::Faker();
my $newuser = {
	'first_name' => $faker->first_name(),
	'last_name' => $faker->last_name(),
	'email' => $email,
	'phone' => '+1'. random_regex('\d{10}'),
	'password' => random_regex('\w{12}'),
	'skip_verify_email' => 0,
	'skip_verify_phone' => 1,
};
print 'Test Data: '. Dumper($newuser);

lives_ok(sub {
	$o->validate_input($newuser);
}, 'validate email') or do {
	print STDERR "Bad TEST_EMAIL environment variable.\n";
	exit(1);
};

if ($ENV{'ENABLE_DB_WRITE'} eq '1')
{
	lives_ok {
		$o->check_duplicate($newuser);
	} 'check duplicate';
	my $uid = $o->create_user($newuser);
	print "Test User ID: $uid\n";
}
else
{
	print "Database Writing Disabled\n";
	foreach my $i (1..1)
	{
		pass("database writing required $i");
	}
}

