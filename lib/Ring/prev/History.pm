package Ring::History;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';

use Ring::User;

no warnings qw(uninitialized);

has 'user' => (
	'is' => 'rw',
	'isa' => 'Ring::User',
	'required' => 1,
);

sub count_call_history
{
	my ($obj) = @_;
	my $uid = $obj->user()->id();
	my $q1 = sqltable('ring_call')->get(
		'array' => 1,
		'result' => 1,
		'select' => ['count(id)'],
		'where' => [
			{
				'target_user_id' => $uid,
			},
			'or',
			{
				'caller_user_id' => $uid,
			},
		],
	);
	return $q1;
}

sub query_call_history
{
	my ($obj, $param) = get_param(@_);
	my $lim = $param->{'limit'};
	my $offset = $param->{'offset'};
	my $order = 'id desc';
	if (defined $lim)
	{
		$order .= ' LIMIT '. $lim;
	}
	if (defined $offset)
	{
		$order .= ' OFFSET '. $offset;
	}
	my $uid = $obj->user()->id();
	my $q1 = sqltable('ring_call')->get(
		'hash' => 1,
		'where' => [
			{
				'target_user_id' => $uid,
			},
			'or',
			{
				'caller_user_id' => $uid,
			},
		],
		'order' => $order,
	);
	if (scalar @$q1)
	{
		my $tgt = join(',', map {$_->{'target_id'}} @$q1);
		my $q2 = sqltable('ring_target')->get(
			'table' => 'ring_target t',
			'select' => [
				't.id',
				't.target_type',
				q|(select email from ring_email e where e.id=t.email_id) as email|,
				q|(select concat(e.did_code, '.', e.did_number) from ring_did e where e.id=t.did_id) as did|,
				q|(select domain from ring_domain e where e.id=t.domain_id) as domain|,
			],
			'where' => "t.id in ($tgt)",
		);
		my %targets = ();
		foreach my $r (@$q2)
		{
			$targets{$r->{'id'}} = $r;
		}
		my $clr = join(',', map {($_->{'caller_user_id'} && $_->{'caller_user_id'} != $uid) ? ($_->{'caller_user_id'}) : ()} @$q1);
		my %callers = ();
		if (length($clr))
		{
			my $q3 = sqltable('ring_user')->get(
				'select' => [
					'id',
					'login',
				],
				'where' => "id in ($clr)",
			);
			foreach my $r (@$q3)
			{
				$callers{$r->{'id'}} = $r;
			}
		}
		foreach my $r (@$q1)
		{
			$r->{'target'} = $targets{$r->{'target_id'}};
			$r->{'caller'} = $callers{$r->{'caller_user_id'}};
		}
	}
	return $q1;
}

1;

