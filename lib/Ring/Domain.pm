package Ring::Domain;
use strict;
use warnings;

use Moose;
use Try::Tiny;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use String::Random;
use Digest::MD5 'md5_hex';
use String::Random 'random_regex';
use Net::DNS;

use Note::SQL::Table 'sqltable', 'transaction';
use Note::Param;
use Note::Row;
use Note::Check;
use Note::XML 'xml';

use Ring::Valid 'validate_phone', 'validate_email', 'split_phone';
use Ring::Exceptions 'throw_duplicate';
use Ring::Item;
use Ring::User;

no warnings qw(uninitialized);

use vars qw();

has 'user' => (
	'is' => 'rw',
	'isa' => 'Ring::User',
	'required' => 1,
);

sub list_domains
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user()->id();
	my $t = sqltable('ring_user_domain');
	my $q;
	if ($param->{'verified'})
	{
		$q = $t->get(
			'table' => ['ring_user_domain u, ring_domain d, ring_target t'],
			'select' => [
				't.id as target_id',
				't.target_type',
				'd.domain',
				'd.id as domain_id',
			],
			'join' => [
				'u.domain_id=d.id',
				'u.domain_id=t.domain_id',
			],
			'where' => {
				'u.user_id' => $uid,
				'u.verified' => 1,
			},
			'order' => 'd.id asc',
		);
	}
	else
	{
		$q = $t->get(
			'table' => ['ring_user_domain u, ring_domain d'],
			'select' => [
				'd.domain',
				'd.id as domain_id',
			],
			'join' => [
				'u.domain_id=d.id',
			],
			'where' => {
				'u.user_id' => $uid,
				'u.verified' => 0,
			},
			'order' => 'd.id asc',
		);
	}
	return $q;
}

sub check_duplicate
{
	my ($obj, $param) = get_param(@_);
	my $c = sqltable('ring_domain')->get(
		'array' => 1,
		'result' => 1,
		'table' => 'ring_domain d, ring_user_domain ud',
		'select' => 'count(ud.id)',
		'join' => 'd.id=ud.domain_id',
		'where' => {
			'd.domain' => $param->{'domain'},
		},
	);
	if ($c == 0)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub create_domain
{
	my ($obj, $param) = get_param(@_);
	my $dns = $param->{'domain'};
	my $uid = $obj->user()->id();
	my $item = new Ring::Item();
	my $drec = $item->item(
		'type' => 'domain',
		'domain' => $dns,
	);
	transaction(sub {
		throw_duplicate(sub {
			Note::Row::create('ring_user_domain' => {
				'domain_id' => $drec->id(),
				'ts_added' => strftime("%F %T", localtime()),
				'user_id' => $uid,
				'verified' => 0,
			});
		});
		my $sr = new String::Random();
		my $code = $sr->randregex('[a-zA-Z0-9]{32}');
		Note::Row::create('ring_verify_domain' => {
			'domain_id' => $drec->id(),
			'ts_added' => strftime("%F %T", localtime()),
			'user_id' => $uid,
			'verified' => 0,
			'verify_code' => $code,
		});
	});
}

sub verify_info
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user()->id();
	my $t = sqltable('ring_user_domain');
	my $q = $t->get(
		'table' => ['ring_user_domain u, ring_domain d, ring_verify_domain v'],
		'select' => [
			'd.domain',
			'd.id as domain_id',
			'v.verify_code',
		],
		'join' => [
			'u.domain_id=d.id',
			'u.domain_id=v.domain_id',
		],
		'where' => {
			'u.user_id' => $uid,
			'u.verified' => 0,
			'd.id' => $param->{'domain_id'},
		},
		'order' => 'd.id asc',
	);
	return $q;
}

sub verify_domain
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->user()->id();
	my $t = sqltable('ring_user_domain');
	my $q = $t->get(
		'table' => ['ring_user_domain u, ring_domain d, ring_verify_domain v'],
		'select' => [
			'd.domain',
			'd.id as domain_id',
			'v.verify_code',
			'u.verified as verified_1',
			'v.verified as verified_2',
		],
		'join' => [
			'u.domain_id=d.id',
			'u.domain_id=v.domain_id',
		],
		'where' => {
			'u.user_id' => $uid,
			'd.id' => $param->{'domain_id'},
		},
		'order' => 'd.id asc',
	);
	unless (scalar(@$q) == 1)
	{
		InvalidUserInput->throw('message' => 'Invalid domain');
	}
	if ($q->[0]->{'verified_1'} || $q->[0]->{'verified_2'})
	{
		DuplicateData->throw('message' => 'Already verified');
	}
	my $code = $q->[0]->{'verify_code'};
	# check DNS record
	my $found = 0;
	eval {
		my $rsv = new Net::DNS::Resolver();
		my $ans = $rsv->query($q->[0]->{'domain'}, 'TXT');
		my @rr = $ans->answer();
		foreach my $rec (@rr)
		{
			my @elms = $rec->txtdata();
			foreach my $e (@elms)
			{
				if ($e =~ /^ringmail-domain-verify\=([a-zA-Z0-9]{32})/)
				{
					my $ic = $1;
					if ($code eq $ic)
					{
						#::log("Found DNS Entry");
						$found = 1;
					}
				}
			}
		}
	};
	unless ($found)
	{
		eval {
			my $lwp = new LWP::UserAgent();
			$lwp->timeout(10);
			my $sc = substr($code, 0, 16);
			my $url = 'http://'. $q->[0]->{'domain'}. '/ringmail_'. $sc. '.html';
			my $rsp = $lwp->get($url);
			if ($rsp->is_success())
			{
				my $c = $rsp->content();
				if ($c =~ /^ringmail-domain-verify\=([a-zA-Z0-9]{32})/)
				{
					my $ic = $1;
					if ($code eq $ic)
					{
						#::log("Found HTTP Document");
						$found = 1;
					}
				}
			}
		};
	}
	::log("Found: $found");
	if ($found && 0)
	{
		my $domid = $q->[0]->{'domain_id'};
		my $ud = new Note::Row(
			'ring_user_domain' => {
				'user_id' => $uid,
				'domain_id' => $domid,
			},
		);
		$ud->update({
			'verified' => 1,
		});
		my $vrd = new Note::Row(
			'ring_verify_domain' => {
				'user_id' => $uid,
				'domain_id' => $domid,
			},
		);
		$vrd->update({
			'verified' => 1,
			'ts_verified' => strftime("%F %T", localtime()),
		});
#		my $add = Ring::API->cmd(
#			'path' => ['user', 'target', 'add', 'domain'],
#			'data' => {
#				'user_id' => $uid,
#				'domain' => $q->[0]->{'domain'},
#			},
#		);
	}
	return $found;
}

1;

