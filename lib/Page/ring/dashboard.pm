package Page::ring::dashboard;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use Regexp::Common 'net';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::API;
use Ring::Contacts;
use Ring::History;

extends 'Page::ring::user';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $val = $obj->value();
	my $user = $obj->user();
	my $rc = new Note::Row(
		'ring_user' => {'id' => $user->id()},
	);
	$content->{'login'} = $rc->data('login');
	my $cts = new Ring::Contacts('user' => $user);
	my $ctc = $cts->count_user_contacts();
	my $ctq = $cts->query_user_contacts(
		'limit' => 8,
		'offset' => 0,
	);
	$content->{'contacts_count'} = $ctc;
	$content->{'contacts_data'} = $ctq;
	$obj->{'format_phone'} = \&format_phone;
	my $hst = new Ring::History('user' => $user);
	my $htc = $hst->count_call_history();
	my $htq = $hst->query_call_history(
		'limit' => 8,
		'offset' => 0,
	);
	$content->{'history_count'} = $htc;
	$content->{'history_data'} = $obj->view_history_data($htq);
	my $uid = $obj->user()->id();
	my $rt = Ring::API->cmd(
		'path' => ['user', 'target', 'list', 'email'],
		'data' => {
			'user_id' => $uid,
			'email' => $content->{'login'},
		},
	);
	if ($rt->{'ok'})
	{
		my $target = Ring::API->cmd(
			'path' => ['user', 'target', 'route'],
			'data' => {
				'user_id' => $uid,
				'target_id' => $rt->{'list'}->[0]->{'target_id'},
			},
		);
		if ($target->{'ok'})
		{
			my $rt = $target->{'route_type'};
			if ($rt eq 'did')
			{
				my $ph = $target->{'did_number'};
				$ph =~ s/(...)(...)(....)/($1) $2-$3/;
				$content->{'route'} = 'Phone Number '. $ph;
			}
			elsif ($rt eq 'app')
			{
				$content->{'route'} = 'RingMail App';
			}
			elsif ($rt eq 'phone')
			{
				$content->{'route'} = 'Phone 1';
			}
			elsif ($rt eq 'sip')
			{
				$content->{'route'} = 'SIP Address: '. $target->{'sip_url'};
			}
		}
	}
	return $obj->SUPER::load($param);
}

sub view_history_data
{
	my ($obj, $data) = @_;
	my @out = ();
	my $uid = $obj->user()->id();
	foreach my $r (@$data)
	{
		my %rec = (
			'ts' => $r->{'ts'},
		);
		my $trec = $r->{'target'};
		my $tname = $trec->{$trec->{'target_type'}};
		if ($r->{'caller_user_id'} == $uid)
		{
			$rec{'direction'} = 'Outgoing';
			$rec{'to'} = $tname;
		}
		else
		{
			$rec{'direction'} = 'Incoming';
			if (defined $r->{'caller'})
			{
				$rec{'from'} = $r->{'caller'}->{'login'};
				$rec{'called'} = $tname;
			}
		}
		push @out, \%rec;
	}
	return \@out;
}

sub format_phone
{
	my ($obj, $data) = @_;
	if ($data->{'did_code'} eq '1')
	{
		my $ph = $data->{'did_number'};
		$ph =~ s/(...)(...)(....)/($1) $2-$3/;
		return $ph;
	}
	else
	{
		return '+'. $data->{'did_code'}. $data->{'did_number'};
	}
}

1;

