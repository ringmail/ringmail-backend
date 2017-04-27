package Ring::BusinessCategory;
use strict;
use warnings;

use vars qw();

use Moose;
use Note::Param;
use POSIX 'strftime';
use LWP::UserAgent;
use JSON::XS;

use Note::Param;
use Note::SQL::Table 'sqltable', 'transaction';

no warnings qw(uninitialized);

sub get_path
{
	my ($obj, $param) = get_param(@_);
	my $catid = $param->{'category_id'};
	my $iter;
	$iter = sub {
		my $cid = shift;
		my $path = shift;
		my $q = sqltable('business_category')->get(
			'array' => 1,
			'select' => ['parent', 'business_category_name'],
			'where' => {
				'id' => $cid,
			},
		);
		unshift @$path, $q->[0]->[1];
		if (defined $q->[0]->[0])
		{
			$iter->($q->[0]->[0], $path);
		}
	};
	my $finalpath = [];
	$iter->($catid, $finalpath);
	return $finalpath;
}

sub get_category_id
{
	my ($obj, $param) = get_param(@_);
	my $path = $param->{'path'};
	my $lastid = undef;
	do {
		my $qry = {
			'business_category_name' => shift(@$path),
		};
		if (defined $lastid)
		{
			$qry->{'parent'} = $lastid,
		}
		my $q = sqltable('business_category')->get(
			'array' => 1,
			'select' => 'id',
			'where' => $qry,
		);
		$lastid = $q->[0]->[0];
	} while (scalar(@$path));
	return $lastid;
}

1;

