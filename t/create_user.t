#!/usr/bin/perl -I/home/note/lib -I/home/note/app/ringmail/lib
use strict;
use warnings;
use Test::More tests => 8;
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

throw_message_ok(sub {
	$o->validate_input(
		'email' => 'baddata',
	);
}, 'InvalidUserInput', 'Invalid email', 'validate email exception');

throw_message_ok(sub {
	$o->validate_input(
		'email' => 'good@data.com',
		'phone' => '555',
	);
}, 'InvalidUserInput', 'Invalid phone', 'validate phone exception');

throw_message_ok(sub {
	$o->validate_input(
		'email' => 'good@data.com',
		'phone' => '+15135230004',
		'first_name' => 'bad$tuff',
	);
}, 'InvalidUserInput', 'Invalid first name', 'validate first_name exception');

throw_message_ok(sub {
	$o->validate_input(
		'email' => 'good@data.com',
		'phone' => '+15135230004',
		'first_name' => 'good',
		'last_name' => 'bad$tuff',
	);
}, 'InvalidUserInput', 'Invalid last name', 'validate last_name exception');

throw_message_ok(sub {
	$o->validate_input(
		'email' => 'good@data.com',
		'phone' => '+15135230004',
		'first_name' => 'good',
		'last_name' => 'good',
		'password' => '123',
	);
}, 'InvalidUserInput', 'Password too short', 'validate password length');

my $faker = new Data::Faker();
my $newuser = {
	'first_name' => $faker->first_name(),
	'last_name' => $faker->last_name(),
	'email' => $faker->email(),
	'phone' => '+1'. random_regex('\d{10}'),
	'password' => random_regex('\w{12}'),
	'skip_verify_email' => 1,
	'skip_verify_phone' => 1,
};
print 'Test Data: '. Dumper($newuser);

if ($ENV{'ENABLE_DB_WRITE'} eq '1')
{
	lives_ok {
		$o->check_duplicate($newuser);
	} 'check duplicate';
	my $uid = $o->create_user($newuser);
	#print "Test User ID: $uid\n";
	throw_message_ok(sub {
		$o->check_duplicate($newuser);
	}, 'DuplicateData', 'Duplicate email', 'duplicate email');
	$newuser->{'email'} = $faker->email();
	#print 'Test Data 2: '. Dumper($newuser);
	throw_message_ok(sub {
		$o->check_duplicate($newuser);
	}, 'DuplicateData', 'Duplicate phone', 'duplicate phone');
}
else
{
	print "Database Writing Disabled\n";
	foreach my $i (1..3)
	{
		pass("database writing required $i");
	}
}

