use strict;
use warnings;
use Test::More tests => 2;
use Carp::Always;
use Data::Dumper;
BEGIN {
	$Note::Config::File = '/home/note/run/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Note::Row');
};

$Note::Row::Database = $Note::Config::Data->storage()->{'sql_note'};
my $row = new Note::Row('note_session_data' => 348120);
my $row2 = $row->row('session_id', 'note_session');
print Dumper($row2->data());
