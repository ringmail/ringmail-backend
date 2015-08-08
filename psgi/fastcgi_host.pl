#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Plack::Handler::FCGI;

use Note::PSGI;

my $root = '/home/note';
my $approot = '/app/note';
my $obj = new Note::PSGI();
$obj->setup(
	'config_file' => $root. '/cfg/note.cfg',
);

my $app = sub {
	$obj->run_psgi(@_);
};

my $server = Plack::Handler::FCGI->new(
	'nproc'  => 3,
	'listen' => ['127.0.0.1:9000'],
	#'detach' => 1,
);
$server->run($app);

