package Test::Process;

#use Note::Process;
use base 'Note::Process';

sub run
{
	my ($obj, $data) = @_;
	if ($data->{'data'} == 2)
	{
		die('2');
	}
	return 1;
}

1;

package main;

use strict;
use warnings;
use Test::More tests => 6;
use Carp::Always;
BEGIN {
	use_ok('Note::Iterator');
	use_ok('Note::Batch');
};

my $iter = new Note::Iterator(
	'array' => [1..3],
);
isa_ok($iter, 'Note::Iterator');
my $batch = new Note::Batch(
	'iterator' => $iter,
	'process' => new Test::Process(),
);
isa_ok($batch, 'Note::Batch');

my $res = $batch->run_batch();

is($res->{'pass'}, 2, 'run batch');
is($res->{'errors'}, 1, 'error count');

