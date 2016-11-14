package Ring::API::User;
use strict;
use warnings;

use vars qw();

use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use Date::Parse 'str2time';
use String::Random;
use Net::DNS;
use Number::Phone::Country;

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::API;
use Ring::API::Base;
use Ring::User;
use Ring::Twilio;

use base 'Ring::API::Base';

no warnings qw(uninitialized);

# create user and request validation of main email
# commands:
#  user create | email: email@address.com, password: secret, phone: 15557779999, first_name: John, last_name: Doe
sub create
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	#print STDERR 'Create: '. Dumper($data);
	my $phone = $data->{'phone'};
	#$phone =~ s/\D//g; # remove +
	#$phone =~ s/^1//;

# Already checked...
#	my $check = Ring::API->cmd(
#		'path' => ['user', 'check', 'user'],
#		'data' => {
#			'email' => $data->{'email'},
#			'phone' => $phone,
#		},
#	);
#	unless ($check->{'ok'})
#	{
#		return $check;
#	}

	$data->{'errors'} = [];
	my $uid = Ring::User::create($data); # create user and send email verification (phase 1)
	my $ok = ($uid) ? 1 : 0;
	if ($ok && defined $data->{'contacts'}) # create contact list
	{
		my $user = new Ring::User($uid);
		my $maxts = 0;
		foreach my $ct (@{$data->{'contacts'}})
		{
			$user->add_contact(
				'contact' => $ct,
			);
			if ($ct->{'ts_updated'} > $maxts)
			{
				$maxts = $ct->{'ts_updated'};
			}
		}
		Note::Row::create('ring_contact_summary' => {
			'user_id' => $uid,
			'ts_updated' => ($maxts) ? strftime("%F %T", gmtime($maxts)) : undef,
			'item_count' => scalar(@{$data->{'contacts'}}),
		});
	}
	if ($ok)
	{
		if (defined $data->{'first_name'} && defined $data->{'last_name'})
		{
			my $rc = Note::Row::create('ring_person', {
				'first_name' => $data->{'first_name'},
				'last_name' => $data->{'last_name'},
			});
			my $userrec = new Note::Row('ring_user' => {'id' => $uid});
			$userrec->update({
				'person' => $rc->id(),
			});
		}
		if (defined($data->{'phone'}) && length($data->{'phone'}))
		{
			my $out = Ring::API->cmd(
				'path' => ['user', 'target', 'verify', 'did', 'generate'],
				'data' => {
					'user_id' => $uid,
					'phone' => $phone,
					'send_sms' => (($data->{'send_sms'}) ? 1 : 0),
				},
			);
			unless ($out->{'ok'})
			{
				::_errorlog("Verify DID Failed: ", $out);
			}
		}
	}
	return {
		'ok' => $ok,
		'user_id' => $uid,
		'prefill' => $data->{'prefill'},
		'errors' => $data->{'errors'},
	};
}

# check if an entity already exists
# user check user | email, phone
# user check email
# user check domain | domain
# user check url
# user check did
sub check
{
	my ($obj, $param) = get_param(@_);
	my $path = $param->{'path'};
	my $data = $param->{'data'};
	my $mode = shift @$path;
#	if ($mode eq 'user')
#	{
#		my $em = $data->{'email'};
#		my $phone = $data->{'phone'};
#		if (sqltable('ring_user')->count('login' => $em))
#		{
#			return {'ok' => 0, 'error_code' => 1, 'error' => 'Duplicate email', 'duplicate' => 'email'}; # duplicate email
#		}
#		if (defined($phone) && length($phone))
#		{
#			$phone =~ s/\D//g;
#			$phone =~ s/^1//;
#			unless (length($phone) == 10) # TODO: update for intl
#			{
#				return {'ok' => 0, 'error_code' => 4, 'error' => 'Invalid phone'}; # invalid phone
#			}
#			my $c = sqltable('ring_did')->get(
#				'array' => 1,
#				'result' => 1,
#				'table' => 'ring_did d, ring_user_did ud',
#				'select' => 'count(ud.id)',
#				'join' => 'd.id=ud.did_id',
#				'where' => {
#					'did_code' => 1,
#					'did_number' => $phone,
#				},
#			);
#			if ($c)
#			{
#				return {'ok' => 0, 'error_code' => 5, 'error' => 'Duplicate phone', 'duplicate' => 'phone'}; # duplicate phone
#			}
#		}
#		if (
#			length($data->{'hashtag'}) &&
#			sqltable('ring_hashtag')->count('hashtag' => $data->{'hashtag'})
#		) {
#			return {'ok' => 0, 'error_code' => 6, 'error' => 'Duplicate hashtag', 'duplicate' => 'hashtag'}; # duplicate hashtag
#		}
#		return {'ok' => 1};
#	}
	elsif ($mode eq 'domain')
	{
		my $c = sqltable('ring_domain')->get(
			'array' => 1,
			'result' => 1,
			'table' => 'ring_domain d, ring_user_domain ud',
			'select' => 'count(ud.id)',
			'join' => 'd.id=ud.domain_id',
			'where' => {
				'd.domain' => $data->{'domain'},
			},
		);
		if ($c)
		{
			return {'ok' => 0};
		}
		return {'ok' => 1};
	}
}

# add a target and request verification
# global params:
#  user_id
# commands:
#  user target add email | email: anonymous
#  user target add email | email: email@address.com
#  user target add did | did: 15557778888
#  user target add domain | domain: domain.com
#  user target add url | url: domain.com/path
#  user target verify email send | email: email@address.com
#  user target verify email check | code: secret
#  user target verify domain generate
#  user target verify domain list
#  user target verify domain check
#  user target verify did generate
#  user target verify did list
#  user target verify did check
#  user target remove | target_id: id
#  user target list
#  user target list email
#  user target list domain
#  user target route
sub target
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $path = $param->{'path'};
	my $mode = shift @$path;
	my $type = shift @$path;
	my $result = {
		'ok' => 0,
	};
	my $uid = $data->{'user_id'};
	unless (defined $uid)
	{
		die('Missing user_id');
	}
	my $urec = new Note::Row(
		'ring_user' => {'id' => $uid},
	);
	unless ($urec->id())
	{
		$result->{'errors'} = ['user_id', 'Invalid user id'];
		return $result;
	}
	if ($mode eq 'add') # add a destination
	{
		if ($type eq 'email')
		{
			my $email = lc($data->{'email'});
			if ($email eq 'anonymous')
			{
				# generate anonymous email
				#$email = 
			}
			else
			{
				unless (Email::Valid->address($email))
				{
					$result->{'errors'} = ['email', 'Invalid email address'];
					return $result;
				}
			}
			my $rec = new Note::Row(
				'ring_email' => {
					'email' => $email,
				},
			);
			if ($rec->id())
			{
				$result->{'errors'} = ['email', 'Email address already in use.'];
				return $result;
			}
			my $item = new Ring::Item();
			my $erec = $item->item(
				'type' => 'email',
				'email' => $email,
			);
			Note::Row::create('ring_user_email' => {
				'email_id' => $erec->id(),
				'user_id' => $uid,
				'primary_email' => 0,
			});
			my $user = new Ring::User($uid);
			my $tid = $user->get_target_id(
				'email_id' => $erec->id(),
			);
			$result->{'ok'} = 1;
			$result->{'target_id'} = $tid;
			$result->{'email_id'} = $erec->id();
			return $result;
		}
		elsif ($type eq 'did')
		{
			my $item = new Ring::Item();
			my $drec = $item->item(
				'type' => 'did',
				'did_number' => $data->{'did_number'},
				'did_code' => $data->{'did_code'},
			);
			my $user = new Ring::User($uid);
			my $tid = $user->get_target_id(
				'did_id' => $drec->id(),
			);
			my $sel = Ring::API->cmd(
				'path' => ['user', 'endpoint', 'select'],
				'data' => {
					'user_id' => $user->id(),
					'target_id' => $tid,
					'endpoint_type' => 'app',
				},
			);
			$result->{'ok'} = 1;
			$result->{'target_id'} = $tid;
			$result->{'did_id'} = $drec->id();
			return $result;
		}
		elsif ($type eq 'domain') # assume unique domain already checked
		{
			my $item = new Ring::Item();
			my $drec = $item->item(
				'type' => 'domain',
				'domain' => $data->{'domain'},
			);
			my $drow = new Note::Row('ring_user_domain' => {
				'domain_id' => $drec->id(),
				'user_id' => $uid,
			});
			unless ($drow->{'id'})
			{
				return {
					'ok' => 0,
					'error' => 'Invalid domain',
				};
			}
			unless ($drow->data('verified'))
			{
				return {
					'ok' => 0,
					'error' => 'Domain not verified',
				};
			}
			my $user = new Ring::User($uid);
			my $tid = $user->get_target_id(
				'domain_id' => $drec->id(),
			);
			$result->{'ok'} = 1;
			$result->{'target_id'} = $tid;
			$result->{'domain_id'} = $drec->id();
			return $result;
		}
	}
	elsif ($mode eq 'verify') # verify ownership of a destination
	{
		if ($type eq 'email')
		{
			my $option = shift @$path;
			if ($option eq 'send')
			{
			}
			elsif ($option eq 'check')
			{
			}
		}
		elsif ($type eq 'domain')
		{
			my $option = shift @$path;
			if ($option eq 'generate')
			{
				my $item = new Ring::Item();
				my $drec = $item->item(
					'type' => 'domain',
					'domain' => $data->{'domain'},
				);
				Note::Row::create('ring_user_domain' => {
					'domain_id' => $drec->id(),
					'ts_added' => strftime("%F %T", localtime()),
					'user_id' => $uid,
					'verified' => 0,
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
				return {
					'ok' => 1,
				};
			}
			elsif ($option eq 'list')
			{
				my %whr = ();
				if ($data->{'domain_id'})
				{
					$whr{'d.id'} = $data->{'domain_id'};
				}
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
						%whr,
					},
					'order' => 'd.id asc',
				);
				$result->{'ok'} = 1;
				$result->{'list'} = $q;
				return $result;
			}
			elsif ($option eq 'check')
			{
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
						'd.id' => $data->{'domain_id'},
					},
					'order' => 'd.id asc',
				);
				unless (scalar(@$q) == 1)
				{
					return {
						'ok' => 0,
						'error' => 'Invalid domain',
					};
				}
				if ($q->[0]->{'verified_1'} || $q->[0]->{'verified_2'})
				{
					return {
						'ok' => 0,
						'error' => 'Already verified',
					};
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
									$found = 1;
								}
							}
						}
					}
				};
				if ($@)
				{
					::_log($@);
					return {
						'ok' => 0,
						'error' => 'DNS lookup failed',
					};
				}
				# check HTML page
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
								$found = 1;
							}
						}
					}
				};
				if ($@)
				{
					::_log($@);
					return {
						'ok' => 0,
						'error' => 'Web request failed',
					};
				}
				# activate domain
				if ($found)
				{
					my $domid = $q->[0]->{'domain_id'};
					my $ud = new Note::Row(
						'ring_user_domain' => {
							'user_id' => $uid,
							'domain_id' => $domid,
						},
					);
					unless ($ud->{'id'})
					{
						return {
							'ok' => 0,
							'error' => 'Invalid domain',
						};
					}
					$ud->update({
						'verified' => 1,
					});
					my $vrd = new Note::Row(
						'ring_verify_domain' => {
							'user_id' => $uid,
							'domain_id' => $domid,
						},
					);
					unless ($vrd->{'id'})
					{
						return {
							'ok' => 0,
							'error' => 'Invalid domain',
						};
					}
					$vrd->update({
						'verified' => 1,
						'ts_verified' => strftime("%F %T", localtime()),
					});
					my $add = Ring::API->cmd(
						'path' => ['user', 'target', 'add', 'domain'],
						'data' => {
							'user_id' => $uid,
							'domain' => $q->[0]->{'domain'},
						},
					);
					unless ($add->{'ok'})
					{
						return {
							'ok' => 0,
							'error' => 'Unable to add domain target',
						};
					}
				}
				return {
					'ok' => $found,
					'error' => ($found) ? '' : 'Verification code not found',
				};
			}
		}
		elsif ($type eq 'did')
		{
			my $option = shift @$path;
			if ($option eq 'generate')
			{
				my $item = new Ring::Item();
				my $phone = $data->{'phone'};
				my ($iso_country_code, $did_code) = Number::Phone::Country::phone2country_and_idd($phone);
				my $did_number = $phone;
				my $ms = "\\+". $did_code;
				my $dm = qr($ms);
				$did_number =~ s/^$dm//;
				#::log("Code: $did_code Subst: $ms Number: $did_number");
				my $drec = $item->item(
					'type' => 'did',
					'did_code' => $did_code,
					'did_number' => $did_number,
				);
				eval {
					$SIG{__WARN__} = sub {};
					local $SIG{__WARN__};	
					Note::Row::create('ring_user_did' => {
						'did_id' => $drec->id(),
						'ts_added' => strftime("%F %T", localtime()),
						'user_id' => $uid,
						'verified' => 0,
					});
				};
				if ($@)
				{
					unless ($@ =~ /duplicate/i) # duplicates ok here
					{
						return {'ok' => 0, 'error' => $@};
					}
				}
				if ($data->{'send_sms'})
				{
					my $sr = new String::Random();
					my $code = $sr->randregex('[0-9]{4}');
					sqltable('ring_verify_did')->delete(
						'where' => {
							'did_id' => $drec->id(),
							'user_id' => $uid,
							'verified' => 0,
						},
					);
					Note::Row::create('ring_verify_did' => {
						'did_id' => $drec->id(),
						'ts_added' => strftime("%F %T", localtime()),
						'user_id' => $uid,
						'verified' => 0,
						'verify_code' => $code,
						'tries' => 0,
					});
					my $msg = 'RingMail Code: '. $code;
					my $tw = new Ring::Twilio();
					my $reply = $tw->send_sms(
						'to' => $phone,
						'from' => '+14243260287',
						'body' => $msg,
					);
					unless ($reply->{'ok'})
					{
						::_errorlog('Send SMS Error', $reply);
					}
				}
				return {
					'ok' => 1,
				};
			}
			elsif ($option eq 'list')
			{
				my %whr = ();
				if ($data->{'did_id'})
				{
					$whr{'d.id'} = $data->{'did_id'};
				}
				my $t = sqltable('ring_user_did');
				my $q = $t->get(
					'table' => ['ring_user_did u, ring_did d, ring_verify_did v'],
					'select' => [
						'd.did_code',
						'd.did_number',
						'd.id as did_id',
						'v.verify_code',
					],
					'join' => [
						'u.did_id=d.id',
						'u.did_id=v.did_id',
					],
					'where' => {
						'u.user_id' => $uid,
						'u.verified' => 0,
						%whr,
					},
					'order' => 'd.id asc',
				);
				$result->{'ok'} = 1;
				$result->{'list'} = $q;
				return $result;
			}
			elsif ($option eq 'check')
			{
				my $t = sqltable('ring_user_did');
				my $q = $t->get(
					'table' => ['ring_user_did u, ring_did d, ring_verify_did v'],
					'select' => [
						'd.did_code',
						'd.did_number',
						'd.id as did_id',
						'v.verify_code',
						'u.verified as verified_1',
						'v.verified as verified_2',
					],
					'join' => [
						'u.did_id=d.id',
						'u.did_id=v.did_id',
					],
					'where' => {
						'u.user_id' => $uid,
						'd.id' => $data->{'did_id'},
					},
					'order' => 'd.id asc',
				);
				unless (scalar(@$q) == 1)
				{
					return {
						'ok' => 0,
						'error' => 'Invalid did',
					};
				}
				if ($q->[0]->{'verified_1'} || $q->[0]->{'verified_2'})
				{
					return {
						'ok' => 0,
						'error' => 'Already verified',
					};
				}
				my $code = $q->[0]->{'verify_code'};
				my $found = ($code eq $data->{'verify_code'}) ? 1 : 0;
				if ($found)
				{
					my $domid = $q->[0]->{'did_id'};
					my $ud = new Note::Row(
						'ring_user_did' => {
							'user_id' => $uid,
							'did_id' => $domid,
						},
					);
					unless ($ud->{'id'})
					{
						return {
							'ok' => 0,
							'error' => 'Invalid did',
						};
					}
					$ud->update({
						'verified' => 1,
					});
					my $vrd = new Note::Row(
						'ring_verify_did' => {
							'user_id' => $uid,
							'did_id' => $domid,
						},
					);
					unless ($vrd->{'id'})
					{
						return {
							'ok' => 0,
							'error' => 'Invalid did',
						};
					}
					$vrd->update({
						'verified' => 1,
						'ts_verified' => strftime("%F %T", localtime()),
					});
					my $add = Ring::API->cmd(
						'path' => ['user', 'target', 'add', 'did'],
						'data' => {
							'user_id' => $uid,
							'did_code' => $q->[0]->{'did_code'},
							'did_number' => $q->[0]->{'did_number'},
						},
					);
					unless ($add->{'ok'})
					{
						return {
							'ok' => 0,
							'error' => 'Unable to add domain target',
						};
					}
				}
				return {
					'ok' => $found,
					'error' => ($found) ? '' : 'Invalid verification code',
				};
			}
		}
	}
	elsif ($mode eq 'remove') # remove a destination
	{
	}
	elsif ($mode eq 'list') # list destinations
	{
		if ($type eq 'email')
		{
			my $t = sqltable('ring_user_email');
			my %whr = ();
			if ($data->{'email'})
			{
				$whr{'e.email'} = $data->{'email'};
			}
			my $q = $t->get(
				'table' => ['ring_user_email u, ring_email e, ring_target t'],
				'select' => [
					't.id as target_id',
					't.target_type',
					't.active',
					'u.primary_email',
					'e.email',
					'e.id as email_id',
				],
				'join' => [
					'u.email_id=e.id',
					'u.email_id=t.email_id',
				],
				'where' => {
					'u.user_id' => $uid,
					%whr,
				},
				'order' => 'u.primary_email desc, e.id asc',
			);
			$result->{'ok'} = 1;
			$result->{'list'} = $q;
			return $result;
		}
		elsif ($type eq 'domain')
		{
			my $t = sqltable('ring_user_domain');
			my $q = $t->get(
				'table' => ['ring_user_domain u, ring_domain d, ring_target t'],
				'select' => [
					't.id as target_id',
					't.target_type',
					#'t.active',
					'1 as active',
					'd.domain',
					'd.id as domain_id',
				],
				'join' => [
					'u.domain_id=d.id',
					'u.domain_id=t.domain_id',
				],
				'where' => {
					'u.user_id' => $uid,
				},
				'order' => 'd.id asc',
			);
			$result->{'ok'} = 1;
			$result->{'list'} = $q;
			return $result;
		}
		else # list all
		{
			my $t = sqltable('ring_target');
			my $q = $t->get(
				'table' => 'ring_target t',
				'select' => [
					'id as target_id',
					'target_type',
					'active',
					'did_id',
					'domain_id',
					'(select domain from ring_domain d where t.domain_id=d.id) as domain',
					'email_id',
					'(select email from ring_email e where t.email_id=e.id) as email',
				],
				'where' => {
					'user_id' => $uid,
				},
				'order' => 'id asc',
			);
			$result->{'ok'} = 1;
			$result->{'list'} = $q;
			return $result;
		}
	}
	elsif ($mode eq 'route')
	{
		my $tid = $data->{'target_id'};
		my $t = sqltable('ring_route');
		my $q = $t->get(
			'result' => 1,
			'table' => 'ring_target_route tr, ring_route r',
			'select' => [
				'r.route_type',
				'r.did_id',
				'r.email_id',
				'r.phone_id',
				'r.sip_id',
			],
			'join' => 'tr.route_id=r.id',
			'where' => {
				'r.user_id' => $uid,
				'tr.target_id' => $tid,
				'tr.seq' => 0,
			},
			'order' => 'r.id desc limit 1',
		);
		if (defined $q)
		{
			$q->{'ok'} = 1;
			my $rt = $q->{'route_type'};
			if ($rt eq 'did')
			{
				my $rec = new Note::Row(
					'ring_did' => {'id' => $q->{'did_id'}},
					'select' => ['did_code', 'did_number'],
				);
				if ($rec->id())
				{
					$q->{'did_code'} = $rec->data('did_code');
					$q->{'did_number'} = $rec->data('did_number');
				}
			}
			elsif ($rt eq 'sip')
			{
				my $rec = new Note::Row(
					'ring_sip' => {'id' => $q->{'sip_id'}},
					'select' => ['sip_url'],
				);
				if ($rec->id())
				{
					$q->{'sip_url'} = $rec->data('sip_url');
				}
			}
			elsif ($rt eq 'email') # routed to another email
			{
			}
			return $q;
		}
		else
		{
			return {
				'ok' => 0,
			};
		}
	}
}

# manage routing endpoints
# global params:
#  user_id
# commands:
#  user endpoint add | type: [ phone | sip | did ]
#  user endpoint remove | endpoint_id: id
#  user endpoint select | target_id, endpoint_type, endpoint_id 
#  user endpoint list
#  user endpoint list sip
#  user endpoint list phone
#  user endpoint list did
sub endpoint
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $path = $param->{'path'};
	my $mode = shift @$path;
	my $uid = $data->{'user_id'};
	unless (defined $uid)
	{
		die('Missing user_id');
	}
	my $urec = new Note::Row(
		'ring_user' => {'id' => $uid},
	);
	unless ($urec->id())
	{
		return {
			'ok ' => 0,
			'errors' => ['user_id', 'Invalid user id'],
		};
	}
	if ($mode eq 'add') # add a destination
	{
		my $type = shift @$path;
		my $item = new Ring::Item();
		if ($type eq 'phone')
		{
			# add VoIP phone
		}
		elsif ($type eq 'did')
		{
			# add Phone Number
			my $drec = $item->item(
				'type' => 'did',
				'did_number' => $data->{'did'},
			);
			return {
				'ok' => 1,
				'endpoint_id' => $drec->{'id'},
			};
		}
		elsif ($type eq 'sip')
		{
			# add SIP Address
			my $drec = $item->item(
				'type' => 'sip',
				'sip_url' => $data->{'sip_url'},
			);
			return {
				'ok' => 1,
				'endpoint_id' => $drec->{'id'},
			};
		}
	}
	elsif ($mode eq 'select') # connect a target to an endpoint
	{
		my $rt = $data->{'endpoint_type'};
		my $epid = $data->{'endpoint_id'};
		my $tgt = $data->{'target_id'};
		my $tbl = Note::Row::table('ring_target_route');
		$tbl->delete(
			'where' => {'target_id' => $tgt},
		);
		if ($rt eq 'none')
		{
			return {'ok' => 1};
		}
		elsif ($rt eq 'did')
		{
			my $rrec = Note::Row::find_create('ring_route' => {
				'route_type' => 'did',
				'did_id' => $epid,
				'user_id' => $uid,
			});
			Note::Row::create('ring_target_route' => {
				'target_id' => $tgt,
				'route_id' => $rrec->id(),
				'seq' => 0,
			});
			return {'ok' => 1};
		}
		elsif ($rt eq 'app')
		{
			my $rrec = Note::Row::find_create('ring_route' => {
				'route_type' => 'app',
				'user_id' => $uid,
			});
			Note::Row::create('ring_target_route' => {
				'target_id' => $tgt,
				'route_id' => $rrec->id(),
				'seq' => 0,
			});
			return {'ok' => 1};
		}
		elsif ($rt eq 'phone')
		{
			my $rrec = Note::Row::find_create('ring_route' => {
				'route_type' => 'phone',
				'phone_id' => $epid,
				'user_id' => $uid,
			});
			Note::Row::create('ring_target_route' => {
				'target_id' => $tgt,
				'route_id' => $rrec->id(),
				'seq' => 0,
			});
			return {'ok' => 1};
		}
		elsif ($rt eq 'sip')
		{
			my $rrec = Note::Row::find_create('ring_route' => {
				'route_type' => 'sip',
				'sip_id' => $epid,
				'user_id' => $uid,
			});
			Note::Row::create('ring_target_route' => {
				'target_id' => $tgt,
				'route_id' => $rrec->id(),
				'seq' => 0,
			});
			return {'ok' => 1};
		}
	}
}

# check login information
sub valid
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $path = $param->{'path'};
	my $lrc = new Note::Row(
		'ring_user' => {'login' => $data->{'login'}},
		'select' => ['password_hash', 'password_salt'],
	);
	unless ($lrc->id())
	{
		return {'ok' => 0};
	}
	my $user = new Ring::User($lrc->id());
	if ($user->check_password({
		'hash' => $lrc->data('password_hash'),
		'salt' => $lrc->data('password_salt'),
		'password' => $data->{'password'},
	}))
	{
		return {'ok' => 1, 'user_id' => $lrc->id()},
	}
	else
	{
		return {'ok' => 0};
	}
}

# manage user contact list
sub contact
{
	my ($obj, $param) = get_param(@_);
	my $data = $param->{'data'};
	my $path = $param->{'path'};
	my $cmd = shift @$path;
	if ($cmd eq 'check_sync')
	{
		my $uid = $data->{'user_id'};
		my $ct = $data->{'item_count'};
		my $ts = $data->{'ts_updated'};
		my $summ = new Note::Row(
			'ring_contact_summary' => {'user_id' => $uid},
			'select' => ['item_count', 'ts_updated'],
		);
		if ($summ->id())
		{
			unless ($ct == $summ->data('item_count')) # item count changed
			{
				return {'ok' => 1, 'sync' => 1};
			}
			if (defined $summ->data('ts_updated'))
			{
				my $tsu = str2time($summ->data('ts_updated'). 'Z');
				if ($data->{'ts_updated'})
				{
					my $remotets = str2time($data->{'ts_updated'});
					unless ($tsu == $remotets) # both ts_updated present, but don't match
					{
						return {'ok' => 1, 'sync' => 1};
					}
				}
			}
			elsif ($ct) # no current ts_updated, has remote items
			{
				return {'ok' => 1, 'sync' => 1};
			}
		}
		elsif ($ct) # no current items, has remote items
		{
			return {'ok' => 1, 'sync' => 1};
		}
		return {'ok' => 1, 'sync' => 0};
	}
	elsif ($cmd eq 'sync')
	{
		my $user = new Ring::User($data->{'user_id'});
		my $cts = $user->get_contacts_hash(
			'apple_id' => $data->{'apple_id'}, # could be undef
		);
		my @add = ();
		my @upd = ();
		my $maxts = 0;
		foreach my $ct (@{$data->{'contacts'}})
		{
			my %rec = (
				'id' => $ct->{'id'},
				'first_name' => $ct->{'fn'},
				'last_name' => $ct->{'ln'},
				'organization' => $ct->{'co'},
				'ts_updated' => str2time($ct->{'ts'}),
				'email' => $ct->{'em'},
				'phone' => $ct->{'ph'},
			);
			if ($rec{'ts_updated'} > $maxts)
			{
				$maxts = $rec{'ts_updated'};
			}
			if (exists $cts->{$rec{'id'}})
			{
				my $cur = $cts->{$rec{'id'}};
				unless ($cur->{'ts_updated'} == $rec{'ts_updated'})
				{
					push @upd, \%rec;
				}
				delete $cts->{$rec{'id'}};
			}
			else
			{
				push @add, \%rec;
			}
		}
		# add
		foreach my $n (@add)
		{
			$user->add_contact(
				'contact' => $n,
			);
		}
		# update
		foreach my $n (@upd)
		{
			$user->update_contact(
				'contact' => $n,
			);
		}
		my $deleted = 0;
		unless (defined $data->{'apple_id'})
		{
			foreach my $k (keys %$cts)
			{
				$user->delete_contact(
					'apple_id' => $cts->{$k}->{'apple_id'},
				);
				$deleted++;
			}
			my $summ = new Note::Row('ring_contact_summary' => {'user_id' => $user->id()});
			my $count = scalar @{$data->{'contacts'}};
			if ($summ->id())
			{
				$summ->update({
					'ts_updated' => ($maxts) ? strftime("%F %T", gmtime($maxts)) : undef,
					'item_count' => $count,
				});
			}
			else
			{
				Note::Row::create('ring_contact_summary' => {
					'user_id' => $user->id(),
					'ts_updated' => ($maxts) ? strftime("%F %T", gmtime($maxts)) : undef,
					'item_count' => $count,
				});
			}
		}
		return {
			'ok' => 1,
			'added' => scalar @add,
			'updated' => scalar @upd,
			'deleted' => $deleted,
		};
	}
	elsif ($cmd eq 'uri')
	{
		my $cts = $data->{'contacts'};
		my $uid = $data->{'user_id'};
		unless (defined $uid)
		{
			die('Missing user_id');
		}
		my %ct = ();
		if (defined($cts) && scalar(@$cts) == 1) # find one, otherwise find all
		{
			$ct{'c.apple_id'} = $cts->[0]->{'id'};
		}
		my $t = sqltable('ring_contact');
		# TODO: check for active route
		my $q = $t->get(
			'hash' => 1,
			'table' => 'ring_contact c, ring_contact_email e, ring_target t',
			'select' => [
				'c.apple_id',
				'(select email from ring_email em where em.id=e.email_id) as email',
			],
			'join' => [
				'c.id=e.contact_id',
				't.email_id=e.email_id',
			],
			'where' => {
				'c.user_id' => $uid,
				%ct,
			},
		);
		my $q2 = $t->get(
			'hash' => 1,
			'table' => 'ring_contact c, ring_contact_phone p, ring_target t',
			'select' => [
				'c.apple_id',
				'(select did_code from ring_did d where d.id=p.did_id) as phone_code',
				'(select did_number from ring_did d where d.id=p.did_id) as phone_number',
			],
			'join' => [
				'c.id=p.contact_id',
				't.did_id=p.did_id',
			],
			'where' => {
				'c.user_id' => $uid,
				%ct,
			},
		);
		my %contacts = ();
		my $data = [];
		foreach my $r (@$q, @$q2)
		{
			if (exists $contacts{$r->{'apple_id'}})
			{
				next;
			}
			else
			{
				if (defined $r->{'phone_code'})
				{
					$r->{'phone_code'} = '+'. $r->{'phone_code'};
				}
				$contacts{$r->{'apple_id'}} = {
					'id' => $r->{'apple_id'},
					'uri' => $r->{'email'} || ($r->{'phone_code'}. $r->{'phone_number'}),
					'reg' => 1,
				};
			}
			my $rc = $contacts{$r->{'apple_id'}};
			push @$data, $rc;
		}
		if (defined($ct{'c.apple_id'}) && scalar(@$data) == 0)
		{
			$data = [{'id' => $ct{'c.apple_id'}}];
		}
		return {'ok' => 1, 'data' => $data};
	}
	return {'ok' => 0};
}

1;

