package Page::ring::setup::domain;
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
	my $phs = $user->get_phones();
	my $out = Ring::API->cmd(
		'path' => ['user', 'target', 'list', 'domain'],
		'data' => {
			'user_id' => $uid,
		},
	);
	::log($out);
	if ($out->{'ok'})
	{
		my $list = $out->{'list'};
		my @domains = ();
		my @domlist = ();
		$content->{'domain_sel'} = '';
		my $id = undef;
		if ($form->{'id'} =~ /^\d+$/)
		{
			$id = $form->{'id'};
		}
		if ((! defined($id)) && scalar @$list)
		{
			$id = $list->[0]->{'domain_id'};
		}
		foreach my $tgt (@$list)
		{
			push @domlist, [$tgt->{'domain'}, $tgt->{'domain_id'}];
			if ($id == $tgt->{'domain_id'})
			{
				my $i = 1;
				my %route = (
					'id' => $i,
					'id_name' => 'route_'. $i,
					'id_did' => 'did_'. $i,
					'id_sip' => 'sip_'. $i,
					'domain' => $tgt->{'domain'},
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
					],
					'selected' => $sel,
				);
				$content->{'domain_rt'} = \%route;
				$content->{'domain_sel'} = $id;
			}
		}
		unless (scalar @domlist)
		{
			@domlist = ['(No Verified Domains)', ''],
		}
		$content->{'domain_opts'} = {'id' => 'domain_sel'};
		if (scalar @domlist)	
		{
			$content->{'domain_opts'}->{'onchange'} = 'this.form.submit();';
		}
		$content->{'domain_list'} = \@domlist;
	}
	my $vout = Ring::API->cmd(
		'path' => ['user', 'target', 'verify', 'domain', 'list'],
		'data' => {
			'user_id' => $uid,
		},
	);
	if ($vout->{'ok'})
	{
		$content->{'verify_count'} = scalar @{$vout->{'list'}};
		$content->{'verify'} = $vout->{'list'};
	}
	return $obj->SUPER::load($param);
}

sub cmd_domain_add
{
	my ($obj, $data, $args) = @_;
	my $dns = lc($data->{'dns'});
	::log("Add Domain: $dns");
	unless (
		(length($dns) >= 3) && # min 3 char
		($dns =~ /\./) && # has a . (dot)
		($dns !~ /\s/) && # does not have a space
		($dns =~ /^$RE{'net'}{'domain'}{'-rfc1101'}$/) # matches this
	) {
		$obj->value()->{'error'} = 'Invalid domain name.';
		$obj->form()->{'new_domain'} = 1;
		return;
	}
	my $ck = Ring::API->cmd(
		'path' => ['user', 'check', 'domain'],
		'data' => {
			'domain' => $dns,
		},
	);
	unless ($ck->{'ok'})
	{
		$obj->value()->{'error'} = 'That domain has already been registered';
		$obj->form()->{'new_domain'} = 1;
		return;
	}
	my $user = $obj->user();
	my $uid = $user->id();
	my $vrf = Ring::API->cmd(
		'path' => ['user', 'target', 'verify', 'domain', 'generate'],
		'data' => {
			'user_id' => $uid,
			'domain' => $dns,
		},
	);
	if ($vrf->{'ok'})
	{
		my $val = $obj->value();
		$val->{'domain_added'} = 1;
		$val->{'domain'} = $dns;
	}
	else
	{
		::log("Generate Verify Error:", $vrf);
		$obj->value()->{'error'} = 'Something went wrong';
		$obj->form()->{'new_domain'} = 1;
	}
}

sub cmd_update
{
	my ($obj, $data, $args) = @_;
	my $content = $obj->content();
	my $user = $obj->user();
	my $uid = $user->id();
	my $val = $obj->value();
	$obj->form()->{'id'} = $args->[1];
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
	my $rid = 1;
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

