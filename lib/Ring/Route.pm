package Ring::Route;
use strict;
use warnings;

use vars qw(%usercheck);

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Email::Valid;
use Authen::Passphrase;
use Authen::Passphrase::SaltedSHA512;
use POSIX 'strftime';
use String::Random;
use MIME::Lite;
#use Net::RabbitMQ;
use JSON::XS 'encode_json';
use Digest::MD5 'md5_base64';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::Item;

no warnings qw(uninitialized);

sub get_target_user_id
{
	my ($obj, $param) = get_param(@_);
	my $dest = $param->{'target'};
	my $type = $obj->get_target_type('target' => $dest);
	my $trow = $obj->get_target(
		'type' => $type,
		$type => $dest,
	);
	if (defined($trow) && $trow->id())
	{
		return $trow->data('user_id');
	}
}

sub get_phone_user
{
	my ($obj, $param) = get_param(@_);
	my $phone = $param->{'phone_login'};
	my $ph = new Note::Row('ring_phone' => {'login' => $phone});
	if ($ph->id())
	{
		return {
			'user_id' => $ph->data('user_id'),
			'login' => $ph->row('user_id', 'ring_user')->data('login'),
		};
	}
	return undef;
}

sub get_target_type
{
	my ($obj, $param) = get_param(@_);
	my $dest = $param->{'target'};
	my $target = undef;
	if ($dest =~ /\@/)
	{
		if (Email::Valid->address($dest))
		{
			$target = 'email';
		}
	}
	elsif ($dest =~ /^\+?\d+$/)
	{
		$target = 'did';
	}
	elsif ($dest =~ /\./ && $dest =~ /^[a-z0-9\.\-]+$/) # domain
	{
		$target = 'domain';
	}
	return $target;
}

sub get_route
{
	my ($obj, $param) = get_param(@_);
	#::_log('Get Route', $param);
	my $item = new Ring::Item();
	my $trow = $obj->get_target($param);
	if (defined($trow) && $trow->{'id'})
	{
		my $tuid = $trow->data('user_id');
		my $tphone = new Note::Row('ring_phone' => {'user_id' => $tuid});
		if ($tphone->id())
		{
			return {
				'phone' => $tphone->data('login'),
			};
		}
# TODO: detailed routing
#		my $troute = new Note::Row('ring_target_route' => {
#			'target_id' => $trow->id(),
#			'seq' => 0,
#		});
#		return undef unless ($troute->id());
#		my $rtrow = $troute->row('route_id', 'ring_route');
#		my $res = $rtrow->data();
#		$res->{'route'} = $rtrow;
#		$res->{'target_id'} = $trow->id();
#		return $res;
	}
	return undef;
}

sub get_target
{
	my ($obj, $param) = get_param(@_);
	#::_log('Get Route', $param);
	my $item = new Ring::Item();
	my $tgt = $param->{'type'};
	my $trec = undef;
	if ($tgt eq 'email')
	{
		my $em = $param->{'email'};
		my $erec = $item->item(
			'type' => 'email',
			'email' => $em,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'email_id' => $erec->id(),
			},
		);
		return $trow;
	}
	elsif ($tgt eq 'domain')
	{
		my $em = $param->{'domain'};
		my $erec = $item->item(
			'type' => 'domain',
			'domain' => $em,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'domain_id' => $erec->id(),
			},
		);
		return $trow;
	}
	elsif ($tgt eq 'did')
	{
		my $num = $param->{'did'};
		my $erec = $item->item(
			'type' => 'did',
			'did_number' => $num,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'did_id' => $erec->id(),
			},
		);
		return $trow;
	}
	return undef;
}

1;

