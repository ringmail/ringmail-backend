use strict;
use warnings;
use Test::More tests => 2;
use Carp::Always;
use Data::Dumper;
BEGIN {
	$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Note::Account');
};

$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

my $owner = 123;
#my $rc = Note::Account::create_account($owner);

my $owner2 = 456;
#my $rc2 = Note::Account::create_account($owner2);
#
my $act1 = new Note::Account($owner);
my $act2 = new Note::Account($owner2);
print Dumper($act1, $act2);

my $type = Note::Account::tx_type_id('test');

my $tx = Note::Account::transaction(
	'acct_dst' => $act1,
	'acct_src' => $act2,
	'amount' => 10,
	'tx_type' => $type,
	'entity' => 789,
	'user_id' => $owner,
);

print "Type: $type TX: $tx\n";

print "Balance 1: ". $act1->balance(). "\n";
print "Balance 2: ". $act2->balance(). "\n";


