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
		my $troute = new Note::Row('ring_target_route' => {
			'target_id' => $trow->id(),
			'seq' => 0,
		});
		return undef unless ($troute->id());
		my $rtrow = $troute->row('route_id', 'ring_route');
		my $res = $rtrow->data();
		$res->{'route'} = $rtrow;
		$res->{'target_id'} = $trow->id();
		return $res;
	}
	return undef;
}

sub get_target
{
	my ($obj, $param) = get_param(@_);
	#::_log('Get Route', $param);
	my $item = new Ring::Item();
	my $tgt = $param->{'target'};
	my $trec = undef;
	if ($tgt eq 'email')
	{
		my $em = $param->{'target_email'};
		my $erec = $item->item(
			'type' => 'email',
			'email' => $em,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'email_id' => $erec->id(),
			},
			'select' => ['active'],
		);
		# TODO: check for active
		return $trow;
	}
	elsif ($tgt eq 'domain')
	{
		my $em = $param->{'target_domain'};
		my $erec = $item->item(
			'type' => 'domain',
			'domain' => $em,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'domain_id' => $erec->id(),
			},
			'select' => ['active'],
		);
		# TODO: check for active
		return $trow;
	}
	elsif ($tgt eq 'did')
	{
		my $num = $param->{'target_did'};
		my $erec = $item->item(
			'type' => 'did',
			'did_number' => $num,
		);
		my $trow = new Note::Row(
			'ring_target' => {
				'did_id' => $erec->id(),
			},
			'select' => ['active'],
		);
		# TODO: check for active
		return $trow;
	}
	return undef;
}

sub get_contact_info
{
	my ($obj, $param) = get_param(@_);
	if (defined $param->{'email'})
	{
		my $res = sqltable('ring_email')->get(
			'hash' => 1,
			'result' => 1,
			'select' => ['c.first_name', 'c.last_name', 'c.organization', 'c.id'],
			'table' => 'ring_email e, ring_contact_email ce, ring_contact c',
			'join' => ['e.id=ce.email_id', 'ce.contact_id=c.id'],
			'where' => {
				'ce.user_id' => $param->{'user_id'},
				'e.email' => $param->{'email'},
			},
		);
		return undef unless (defined $res);
		my @pts = ();
		my $name = '';
		if (length($res->{'first_name'}))
		{
			push @pts, $res->{'first_name'};
		}
		if (length($res->{'last_name'}))
		{
			push @pts, $res->{'last_name'};
		}
		if (scalar @pts)
		{
			$name = join(' ', @pts);
		}
		elsif (length($res->{'organization'}))
		{
			$name = $res->{'organization'};
		}
		return {
			'name' => $name,
			'id' => $res->{'id'},
		};
	}
	return undef;
}

sub get_route_fs
{
	my ($obj, $rt, $hostref) = @_;
	my $host = $rt->{'hostname'};
	if ($rt->{'route_type'} eq 'did')
	{
		my $drec = $rt->{'route'}->row('did_id', 'ring_did');
		my $rtdid = $drec->data('did_number');
		return q|sofia/gateway/flowroute/1|. $rtdid;
	}
	elsif ($rt->{'route_type'} eq 'app')
	{
		my $uid = $rt->{'user_id'};
		my $urec = new Note::Row('ring_user' => $uid, {'select' => ['login']});
		my $ext = $urec->data('login');
		$ext =~ s/\@/%40/;
		my $siphost = $obj->get_sip_host($ext);
		if (defined $siphost)
		{
### Kamailio
				$ext =~ s/\%40/\*/;
				my $sip = "$ext\@$siphost;transport=tcp";
				return 'sofia/internal/'. $sip;
### Freeswitch
#			if ($siphost eq $host)
#			{
#				return qq|\${sofia_contact($ext)}|;
#			}
#			else
#			{
#				if (ref $hostref)
#				{
#					$$hostref = $siphost;
#				}
#				if ($siphost !~ /\./ && $siphost =~ /^ip\-/) # Amazon EC2
#				{
#					$siphost .= '.ec2.internal';
#				}
#				my $sip = "$ext\@$siphost";
#				return 'sofia/external/'. $sip;
#			}
		}
		else
		{
			return undef;
		}
	}
	elsif ($rt->{'route_type'} eq 'phone')
	{
		my $drec = $rt->{'route'}->row('phone_id', 'ring_phone');
		my $ext = $drec->data('login');
		my $siphost = $obj->get_sip_host($ext);
		if (defined $siphost)
		{
			if ($siphost eq $host)
			{
				return qq|\${sofia_contact($ext)}|;
			}
			else
			{
				if ($siphost !~ /\./ && $siphost =~ /^ip\-/) # Amazon EC2
				{
					$siphost .= '.ec2.internal';
				}
				my $sip = "p_$ext\@$siphost";
				return 'sofia/external/'. $sip;
			}
		}
		else
		{
			return undef;
		}
		#return 'sofia/gateway/phone/'. $ext. '@link1st.com';
	}
	elsif ($rt->{'route_type'} eq 'sip')
	{
		my $drec = $rt->{'route'}->row('sip_id', 'ring_sip');
		my $sip = $drec->data('sip_url');
		return 'sofia/external/'. $sip;
	}
}

sub get_sip_host
{
	my ($obj, $sipuser) = @_;
### Kamailio
	my $fsdb = $main::note_config->storage()->{'rgm_openser'};
	my $tbl = $fsdb->table('subscriber_proxy');
	my $q = $tbl->get(
		'array' => 1,
		'result' => 1,
		'select' => ['proxy'],
		'where' => {
			'username' => $sipuser,
		},
	);
### Freeswitch
#	my $fsdb = $main::note_config->storage()->{'rgm_freeswitch'};
#	my $tbl = $fsdb->table('sip_registrations');
#	my $q = $tbl->get(
#		'array' => 1,
#		'result' => 1,
#		'select' => ['hostname'],
#		'where' => {
#			'sip_user' => $sipuser,
#		},
#	);
	return $q;
}

# unused
sub get_sip_contact
{
	my ($obj, $sipuser) = @_;
	my $fsdb = $main::note_config->storage()->{'rgm_freeswitch'};
	my $tbl = $fsdb->table('sip_registrations');
	my $q = $tbl->get(
		'array' => 1,
		'result' => 1,
		'select' => ['contact'],
		'where' => {
			'sip_user' => $sipuser,
		},
	);
	return $q;
}

sub send_request
{
	my ($obj, $cmd, $req) = @_;
	my %rabbit = (
		'host' => 'localhost',
		'port' => 5673,
		'user' => 'guest',
		'password' => 'guest',
	);
	my $host = $req->{'queuehost'};
	delete $req->{'queuehost'};
	my $json = encode_json([$cmd, $req]);
#	my $rbq = new Net::RabbitMQ();
#	$rbq->connect($rabbit{'host'}, {
#		'user' => $rabbit{'user'},
#		'password' => $rabbit{'password'},
#		'port' => $rabbit{'port'},
#	});
#	$rbq->channel_open(1);
#	$rbq->publish(1, 'rgm_'. $host, $json, {'exchange' => 'ringmail'});
#	$rbq->disconnect();
	::_log("Send($host): $cmd", $req);
}

sub get_login_info
{
	my ($obj, $param) = get_param(@_);
	if ($param->{'source'} eq 'sms_gateway')
	{
		return {
			'type' => 'sms',
		};
	}
	my $ph = $param->{'phone'};
	if ($ph =~ /\%40/) # check for user login email
	{
		$ph =~ s/\%40/\@/;
		my $login = sqltable('ring_user')->get(
			'array' => 1,
			'select' => ['login', 'id'],
			'where' => {
				'login' => $ph,
			},
		);
		if (scalar @$login)
		{
			return {
				'type' => 'app',
				'login' => $login->[0]->[0],
				'user_id' => $login->[0]->[1],
			};
		}
	}
	else # check for phone login
	{
		my $login = sqltable('ring_user')->get(
			'array' => 1,
			'select' => ['u.login', 'p.id', 'u.id'],
			'table' => 'ring_user u, ring_phone p',
			'join' => 'u.id=p.user_id',
			'where' => {
				'p.login' => $ph,
			},
		);
		if (scalar @$login)
		{
			return {
				'type' => 'phone',
				'login' => $login->[0]->[0],
				'phone_id' => $login->[0]->[1],
				'user_id' => $login->[0]->[2],
			};
		}
	}
	return undef; # something went wrong
}

sub get_queue_host
{
	my ($obj, $hostname) = @_;
	my $rc = new Note::Row(
		'ring_server_voip' => {
			'host_name' => $hostname,
		},
		'select' => ['host_queue'],
	);
	if ($rc->{'id'})
	{
		return $rc->data('host_queue');
	}
	else
	{
		die(qq|Queue hostname not found for: '$hostname'|);
	}
}

sub get_host_name
{
	my ($obj, $qname) = @_;
	my $rc = new Note::Row(
		'ring_server_voip' => {
			'host_queue' => $qname,
		},
		'select' => ['host_name'],
	);
	if ($rc->{'id'})
	{
		return $rc->data('host_name');
	}
	else
	{
		die(qq|Host name not found for queue host: '$qname'|);
	}
}

sub register_server
{
	my ($obj, $param) = get_param(@_);
	my $rc = new Note::Row(
		'ring_server_voip' => {
			'host_queue' => $param->{'host_queue'},
		},
	);
	if ($rc->{'id'})
	{
		$rc->update({
			'host_name' => $param->{'host_name'},
		});
	}
	else
	{
		Note::Row::create(
			'ring_server_voip' => {
				'host_queue' => $param->{'host_queue'},
				'host_name' => $param->{'host_name'},
			},
		);
	}
}

sub get_random_server
{
	my ($obj) = @_;
	my $tbl = sqltable('ring_server_voip');
	my $ct = $tbl->count();
	my $rnd = int(rand($ct));
	my $res = $tbl->get(
		'array' => 1,
		'result' => 1,
		'select' => ['host_queue'],
		'order' => 'id asc limit 1 offset '. $rnd,
	);
}

1;

