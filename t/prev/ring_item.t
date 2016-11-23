use strict;
use warnings;
use Test::More tests => 4;
use Carp::Always;
use Data::Dumper;
BEGIN {
	$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Ring::Item');
};

$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

my $item = new Ring::Item();
my $did = $item->item(
	'type' => 'did',
	'did_number' => '12133697501',
);
is($did->data()->{'did_number'}, '2133697501', 'DID match');
my $sip = $item->item(
	'type' => 'sip',
	'sip_url' => '200@sip.dyl.com',
);
is($sip->data()->{'sip_url'}, '200@sip.dyl.com', 'SIP match');

