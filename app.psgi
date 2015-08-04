#!/usr/bin/perl

use Data::Dumper;
use JSON::XS;
use DBI;
use DBIx::Connector;
use Plack::Builder;

use Note::PSGI;

my $obj = new Note::PSGI();
my $root = '/home/note/run';
$obj->setup(
	'config_file' => $root. '/cfg/note.cfg',
);

my $app = sub {
	$obj->run_psgi(@_);
};

builder {
    enable "Plack::Middleware::Static",
        'path' => sub { s{^/ext/}{} },
        'root' => $root. '/app/note'. '/static/ext/';
    enable "Plack::Middleware::Static",
        'path' => sub { s{^/img/}{} },
        'root' => $root. '/app/note'. '/static/img/';
    enable "Plack::Middleware::Static",
        'path' => sub { s{^/css/}{} },
        'root' => $root. '/app/note'. '/static/css/';
    enable "Plack::Middleware::Static",
        'path' => sub { s{^/js/}{} },
        'root' => $root. '/app/note'. '/static/js/';
    enable "Plack::Middleware::Static",
        'path' => sub { m{^/favicon.ico} },
        'root' => $root. '/app/note'. '/static/img/';
    $app;
};

#print STDERR 'Start: '. Dumper(\%ENV);
# Stackato / Cloud Foundry Database
#if ($ENV{'VCAP_SERVICES'})
#{
#	my $svcs = decode_json($ENV{'VCAP_SERVICES'});
#	print STDERR 'Services: '. Dumper($svcs);
#	if ($svcs->{'mysql-5.1'})
#	{
#		my $mysql = $svcs->{'mysql-5.1'}->[0]->{'credentials'};
#		my $dsn = 'DBI:mysql:database='. $mysql->{'name'}. ';host='. $mysql->{'hostname'}. ';port='. $mysql->{'port'};
#		my $dbh = new DBIx::Connector($dsn, $mysql->{'user'}, $mysql->{'password'}, {
#			'PrintError' => 0,
#			'RaiseError' => 1,
#			#'TraceLevel' => '1|SQL',
#		});
#		$Note::SQL::Table::DATABASE = $dbh;
#	}
#}

