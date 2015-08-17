package Page::ring::setup::email;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::API;

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
	my $uid = $user->id();

	# setup phone
	my $phs = $user->get_phones();
	unless (scalar @$phs)
	{
		$user->add_phone();
		$phs = $user->get_phones();
	}

	my $out = Ring::API->cmd(
		'path' => ['user', 'target', 'list', 'email'],
		'data' => {
			'user_id' => $uid,
		},
	);
	::_log($out);
	if ($out->{'ok'})
	{
		my $list = $out->{'list'};
		my @emails = ();
		my $i = 0;
		foreach my $tgt (@$list)
		{
			$i++;
			my %route = (
				'id' => $i,
				'id_name' => 'route_'. $i,
				'id_did' => 'did_'. $i,
				'id_sip' => 'sip_'. $i,
				'email' => $tgt->{'email'},
				'primary' => $tgt->{'primary_email'},
				'active' => $tgt->{'active'},
				'target_id' => $tgt->{'target_id'},
				'did_opts' => {},
			);
			my $target = Ring::API->cmd(
				'path' => ['user', 'target', 'route'],
				'data' => {
					'user_id' => $uid,
					'target_id' => $tgt->{'target_id'},
				},
			);
			my $sel = $uid;
			if ($target->{'ok'})
			{
				my $rt = $target->{'route_type'};
				if ($rt eq 'did')
				{
					my $ph = $target->{'did_number'};
					$ph =~ s/(...)(...)(....)/($1) $2-$3/;
					$route{'did'} = 1;
					$route{'did_number'} = $ph;
					$route{'route'} = 'Phone Number '. $ph;
				}
				elsif ($rt eq 'app')
				{
					$route{'phone'} = 1;
					$route{'route'} = 'RingMail App';
				}
				elsif ($rt eq 'phone')
				{
					$route{'phone'} = 1;
					$route{'route'} = 'Phone 1';
					$sel = $target->{'phone_id'};
				}
				elsif ($rt eq 'sip')
				{
					$route{'sip'} = 1;
					$route{'sip_url'} = $target->{'sip_url'};
					$route{'route'} = 'SIP Address: '. $target->{'sip_url'};
				}
			}
			$route{'phone_field'} = $obj->field(
				'command' => 'update',
				'name' => 'phone_'. $i,
				'type' => 'select',
				'select' => [
					['RingMail App', $user->id()],
					['Phone 1', $phs->[0]->{'id'}],
				],
				'selected' => $sel,
			);
			push @emails, \%route;
		}
		$content->{'emails'} = \@emails;
		$content->{'sel'} = $val->{'sel'} || 1;
	}
	return $obj->SUPER::load($param);
}

sub cmd_update
{
	my ($obj, $data, $args) = @_;
	my $content = $obj->content();
	my $user = $obj->user();
	my $uid = $user->id();
	my $val = $obj->value();
	$val->{'sel'} = $args->[1];
	my $usertgt = new Note::Row(
		'ring_target' => {
			'id' => $args->[0],
			'user_id' => $uid,
		},
	);
	unless ($usertgt->id()) # invalid target
	{
		return;
	}
	my $rid = $args->[1];
	my $route = $data->{'route_'. $rid};
	my $endp = $data->{$route. '_'. $rid};
	my $epadd;
	if ($route eq 'did')
	{
		$endp =~ s/\D//g;
		$endp =~ s/^1//;
		unless ($endp =~ /^\d{10}$/)
		{
			$val->{'error'} = 'Invalid phone number.';
			return;
		}
		$epadd = Ring::API->cmd(
			'path' => ['user', 'endpoint', 'add', 'did'],
			'data' => {
				'user_id' => $uid,
				'did' => $endp,
			},
		);
	}
	elsif ($route eq 'phone')
	{
		if ($endp == $uid)
		{
			$route = 'app';
			$epadd = {'ok' => 1};
		}
		else
		{
			my $phrec = new Note::Row(
				'ring_phone' => {
					'id' => $endp,
					'user_id' => $uid,
				},
			);
			unless ($phrec->id()) # invalid phone
			{
				return;
			}
			$epadd = {
				'ok' => 1,
				'endpoint_id' => $phrec->id(),
			};
		}
	}
	elsif ($route eq 'sip')
	{
		# TODO: check for valid SIP address
		#
		#unless (Email::Valid->address($endp)) # invalid sip url
		#{
		#	$val->{'error'} = 'Invalid SIP Address.';
		#	return;
		#}
		$epadd = Ring::API->cmd(
			'path' => ['user', 'endpoint', 'add', 'sip'],
			'data' => {
				'user_id' => $uid,
				'sip_url' => $endp,
			},
		);
	}
	if ($epadd->{'ok'})
	{
		my $setrt = Ring::API->cmd(
			'path' => ['user', 'endpoint', 'select'],
			'data' => {
				'user_id' => $uid,
				'target_id' => $usertgt->id(),
				'endpoint_type' => $route,
				'endpoint_id' => $epadd->{'endpoint_id'},
			},
		);
	}
}

1;

