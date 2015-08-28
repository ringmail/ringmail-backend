package Ring::HashtagFactory;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::User;

no warnings qw(uninitialized);

sub validate
{
	my ($obj, $param) = get_param(@_);
	my $tag = $param->{'tag'};
	if ($tag =~ /^[a-z0-9_]+$/)
	{
		return 1;
	}
	return 0;
}

sub check_exists
{
	my ($obj, $param) = get_param(@_);
	my $tag = lc($param->{'tag'});
	unless ($obj->validate(
		'tag' => $tag,
	)) {
		die(qq|Invalid hashtag: '$tag'|);
	}
	return sqltable('ring_hashtag')->count(
		'hashtag' => $tag,
	);
}

sub create
{
	my ($obj, $param) = get_param(@_);
	my $tag = lc($param->{'tag'});
	unless ($obj->validate(
		'tag' => $tag,
	)) {
		die(qq|Invalid hashtag: '$tag'|);
	}
	my $uid = $param->{'user_id'};
	my $url = $param->{'target_url'};
	my $expires = $param->{'expires'};
	my $trec;
	eval {
		$trec = Note::Row::create('ring_hashtag', {
			'hashtag' => $tag,
			'user_id' => $uid,
			'target_url' => $url,
			'ts_expires' => $expires,
		});
	};
	if ($@)
	{
		my $err = $@;
		if ($err =~ /Duplicate/)
		{
			return undef;
		}
		else
		{
			die($err);
		}
	}
	return $trec;
}

sub get_user_hashtags
{
	my ($obj, $param) = get_param(@_);
	my $uid = $param->{'user_id'};
	my $q = sqltable('ring_hashtag')->get(
		'select' => ['id', 'hashtag', 'ts_expires as expires', 'target_url'],
		'where' => {
			'user_id' => $uid,
		},
		'order' => 'hashtag asc',
		'limit' => '10',
	);
	return $q;
}

1;

