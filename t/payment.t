use strict;
use warnings;
use Test::More tests => 3;
use Carp::Always;
use Data::Dumper;
BEGIN {
	$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Note::Account');
	use_ok('Note::Payment');
};

$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

my $owner = 5244;
#my $rc = Note::Account::create_account($owner);

my $act = new Note::Account($owner);
print "Balance 1: ". $act->balance(). "\n";

my $pmt = new Note::Payment($owner);
my $cid = $pmt->card_add(
	'num' => '6011000990139424',
	'cvv2' => '234',
	'type' => 'Discover',
	'expy' => '2020',
	'expm' => '01',
	'first_name' => 'John',
	'last_name' => 'Doe',
	'address' => '123 Front St',
	'address2' => 'Apt 2',
	'city' => 'Oxford',
	'state' => 'OH',
	'zip' => '45056',
);

print "Card: $cid\n";

my $pid = $pmt->card_payment(
	'processor' => 'paypal',
	'nofork' => 1,
	'amount' => 25.01,
	'card_id' => $cid,
	'ip' => '127.0.0.1',
);

print "Payment: $pid\n";

print "Balance 2: ". $act->balance(). "\n";

