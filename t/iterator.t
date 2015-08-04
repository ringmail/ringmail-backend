package Test::Process;

#use Note::Process;
use base 'Note::Process';

sub run
{
	my ($obj, $data) = @_;
	#print "[$data->{'data'}]\n";
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

my @data = ();
while (my $l = <DATA>)
{
	push @data, $l;
}
my $iter = new Note::Iterator(
	'array' => \@data,
);
isa_ok($iter, 'Note::Iterator');
my $batch = new Note::Batch(
	'iterator' => $iter,
	'process' => new Test::Process(),
);
isa_ok($batch, 'Note::Batch');

my $res = $batch->run_batch();

is($res->{'pass'}, 3, 'run batch');
is($res->{'errors'}, 0, 'error count');


__DATA__
Test Line 1
Test Line 2
Test Line 3
