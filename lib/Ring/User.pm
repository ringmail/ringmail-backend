package Ring::User;
use strict;
use warnings;

use vars qw(%usercheck);

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Email::Valid;
use Math::Random::Secure;
use Authen::Passphrase;
use Authen::Passphrase::SaltedSHA512;
use POSIX 'strftime';
use String::Random;
use MIME::Lite;
use Digest::MD5 'md5_hex';
use URI::Encode 'uri_encode';
use Date::Parse 'str2time';

use Note::SQL::Table 'sqltable';
use Note::Param;
use Note::Row;
use Note::Check;
use Note::XML 'xml';
use Note::Template;
use Ring::Item;
use Ring::Route;
use Ring::API;

no warnings qw(uninitialized);

has 'id' => (
	'is' => 'rw',
	'isa' => 'Int',
);

our %usercheck = (
#	'first_name' => new Note::Check(
#		'type' => 'regex',
#		'chars' => 'A-Za-z0-9.- ',
#	),
#	'last_name' => new Note::Check(
#		'type' => 'regex',
#		'chars' => 'A-Za-z0-9.- ',
#	),
	'email' => new Note::Check(
		'type' => 'valid',
		'valid' => sub {
			my ($sp, $data) = @_;
			unless (Email::Valid->address($$data))
			{
				Note::Check::fail('Invalid email address');
			}
			my $r = new Note::Row('ring_user' => {
				'login' => $$data,
			});
			if ($r->id())
			{
				Note::Check::fail('Another user is already registered with that email address');
			}
			return 1;
		},
	),
);

# static method
sub create
{
	my ($param) = @_;
	my $errors = $param->{'errors'};
	unless (ref($errors) && reftype($errors) eq 'ARRAY')
	{
		die('Invalid errors parameter');
	}
	my $rec = {};
	foreach my $k (qw/email/)
	{
		my $dv = $param->{$k};
		$dv =~ s/^\s+//;
		$dv =~ s/\s+$//;
		my $ck = $usercheck{$k};
		if ($ck->valid(\$dv))
		{
			$rec->{$k} = $dv;
		}
		else
		{
			push @$errors, [$k, $ck->error()];
		}
	}
	%{$param->{'prefill'}} = %$rec;
	if (scalar @$errors)
	{
		return 0;
	}
	unless (length($param->{'password'}) > 3)
	{
		push @$errors, ['password', 'Password must be at least 4 characters long.'];
		return 0;
	}
	unless ($param->{'password'} eq $param->{'password2'})
	{
		push @$errors, ['password', 'Password do not match.'];
		return 0;
	}
	# create the user
	open (S, '-|', '/home/mfrager/note/perl/ringmail/gensalt.pl');
	$/ = undef;
	my $salt = <S>;
	close(S);
	my $gen = new Authen::Passphrase::SaltedDigest(
		'passphrase' => $param->{'password'},
		'salt_hex' => $salt,
		'algorithm' => 'SHA-512',
	);
	$salt = $gen->salt_hex();
	my $hash = $gen->hash_hex();
	my $fsdomain = $::app_config->{'fs_domain'};
	my @pts = split /\@/, $rec->{'email'};
	my $em = $rec->{'email'};
	$em =~ s/\@/\%40/;
	my $fslogin = $em. ':'. $fsdomain. ':'. $param->{'password'};
	#::_log("F: $fslogin");
	my $urec = undef;
	eval {
		$urec = Note::Row::create('ring_user' => {
			'active' => 1,
			'login' => $rec->{'email'},
			'password_fs' => md5_hex($fslogin),
			'password_hash' => $hash,
			'password_salt' => $salt,
			'person' => 0, # update next
			'verified' => 0,
			#'verified' => 1, # For testing
		});
	};
	if ($@)
	{
		push @$errors, ['create', 'An error occurred creating account.'];
		return 0;
	}
	my $fsdb = $main::note_config->storage()->{'rgm_openser'};
	$fsdb->table('subscriber')->set(
		'insert' => {
			'username' => $em,
			'domain' => 'sip.ringmail.com',
			'ha1' => md5_hex($fslogin),
		},
	);
	my $item = new Ring::Item();
	my $erec = $item->item(
		'type' => 'email',
		'email' => $rec->{'email'},
	);
	Note::Row::create('ring_user_email' => {
		'email_id' => $erec->id(),
		'user_id' => $urec->id(),
		'primary_email' => 1,
	});
	my $user = new Ring::User($urec->id());
	my $tid = $user->get_target_id(
		'email_id' => $erec->id(),
	);
	my $sel = Ring::API->cmd(
		'path' => ['user', 'endpoint', 'select'],
		'data' => {
			'user_id' => $user->id(),
			'target_id' => $tid,
			'endpoint_type' => 'app',
		},
	);
	$user->verify_email_send(
		'email' => $rec->{'email'},
	);
	return $urec->id();
}

sub BUILDARGS
{
	my $class = shift;
	if ($#_ == 0)
	{
		return (ref($_[0])) ? $_[0] : {'id' => $_[0]};
	}
	else
	{
		return {@_};
	}
}

sub reset_email_send
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $item = new Ring::Item();
	my $erec = $item->item(
		'type' => 'email',
		'email' => $param->{'email'},
	);
	my $sr = new String::Random();
	my $code = $sr->randregex('[a-zA-Z0-9]{500}');
	$code = md5_hex($code);
	my $rc = Note::Row::find_create(
		'ring_user_pwreset' => {
			'user_id' => $uid,
		},
		{
			'ts' => strftime("%F %T", localtime()),
		},
	);
	$rc->update({'reset_hash' => $code});
	my $from = 'RingMail <ringmail@ringmail.com>';
	my $link = 'https://www.ringmail.com/reset?code='. $code;
	my $tmpl = new Note::Template(
		'root' => $main::note_config->{'root'}. '/app/ringmail/template',
	);
	my $txt = $tmpl->template('email/reset_pass.txt', {
		'link' => $link,
		'email' => $param->{'email'},
	});
	my $html = $tmpl->template('email/reset_pass.html', {
		'link' => $link,
		'email' => $param->{'email'},
	});
	my $msg = new MIME::Lite(
		'To' => $param->{'email'},
		'From' => $from,
		'Subject' => 'RingMail Password Reset',
		'Type' => 'multipart/alternative',
		'Data' => $txt,
	);
	my $msgtxt = new MIME::Lite(
		'Type' => 'text/plain; charset="iso-8859-1"',
		'Data' => $txt,
	);
	my $msghtml = new MIME::Lite(
		'Type' => 'text/html; charset="iso-8859-1"',
		'Data' => $html,
	);
	$msg->attach($msgtxt);
	$msg->attach($msghtml);
	eval {
		$msg->send(
			'smtp' => 'localhost',
			'Timeout' => 10,
		);
	};
	if ($@)
	{
		::_errorlog('Email Error:', $@);
	}
	return 1;
}

sub verify_email_send
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $item = new Ring::Item();
	my $erec = $item->item(
		'type' => 'email',
		'email' => $param->{'email'},
	);
	my $sr = new String::Random();
	my $code = $sr->randregex('[a-zA-Z0-9]{32}');
	my $rc = Note::Row::find_create(
		'ring_verify_email' => {
			'email_id' => $erec->id(),
		},
		{
			'ts_added' => strftime("%F %T", localtime()),
			'user_id' => $uid,
			'verify_code' => '',
		},
	);
	$rc->update({
		'verified' => 0,
		'verify_code' => $code,
	});
	my $from = 'RingMail <ringmail@ringmail.com>';
	my $link = 'https://www.ringmail.com/verify?code='. $code;
	my $tmpl = new Note::Template(
		'root' => $main::note_config->{'root'}. '/app/ringmail/template',
	);
	my $txt = $tmpl->template('email/verify.txt', {
		'link' => $link,
	});
	my $html = $tmpl->template('email/verify.html', {
		'link' => $link,
	});
	my $msg = new MIME::Lite(
		'To' => $param->{'email'},
		'From' => $from,
		'Subject' => 'Confirm Email Address',
		'Type' => 'multipart/alternative',
		'Data' => $txt,
	);
	my $msgtxt = new MIME::Lite(
		'Type' => 'text/plain; charset="iso-8859-1"',
		'Data' => $txt,
	);
	my $msghtml = new MIME::Lite(
		'Type' => 'text/html; charset="iso-8859-1"',
		'Data' => $html,
	);
	$msg->attach($msgtxt);
	$msg->attach($msghtml);
	eval {
		$msg->send(
			'smtp' => 'localhost',
			'Timeout' => 10,
		);
	};
	if ($@)
	{
		::_errorlog('Email Error:', $@);
	}
	return 1;
}

sub verify_email
{
	my ($obj, $param) = get_param(@_);
	my $rec = $param->{'record'};
	if ($rec->data('verified'))
	{
		return 0;
	}
	$rec->update({
		'ts_verified' => strftime("%F %T", localtime()),
		'verified' => 1,
	});
	my $erec = new Note::Row(
		'ring_user_email' => {
			'email_id' => $rec->data('email_id'),
			'user_id' => $rec->data('user_id'),
		},
		{
			'select' => [qw/primary_email/],
		},
	);
	if ($erec->data('primary_email'))
	{
		my $urec = new Note::Row(
			'ring_user' => $obj->id(),
		);
		$urec->update({
			'verified' => 1,
		});
	}
}

sub check_password
{
	my ($obj, $param) = get_param(@_);
	my $auth = new Authen::Passphrase::SaltedSHA512(
		'salt_hex' => $param->{'salt'},
		'hash_hex' => $param->{'hash'},
	);
	return 1 if  ($auth->match($param->{'password'}));
	return 0;
}

sub password_change
{
	my ($obj, $param) = get_param(@_);
	my $pass = $param->{'password'};
	open (S, '-|', '/home/mfrager/note/perl/ringmail/gensalt.pl');
	$/ = undef;
	my $salt = <S>;
	close(S);
	my $gen = new Authen::Passphrase::SaltedDigest(
		'passphrase' => $pass,
		'salt_hex' => $salt,
		'algorithm' => 'SHA-512',
	);
	$salt = $gen->salt_hex();
	my $hash = $gen->hash_hex();
	my $fsdomain = $::app_config->{'fs_domain'};
	my $urec = new Note::Row(
		'ring_user' => {'id' => $obj->id()},
		'select' => ['login'],
	);
	my $email = $urec->data('login');
	my @pts = split /\@/, $email;
	$email =~ s/\@/\%40/;
	my $fslogin = $email. ':'. $fsdomain. ':'. $pass;
	$urec->update({
		'password_fs' => md5_hex($fslogin),
		'password_hash' => $hash,
		'password_salt' => $salt,
	});
	my $fsdb = $main::note_config->storage()->{'rgm_openser'};
	$fsdb->table('subscriber')->set(
		'update' => {
			'ha1' => md5_hex($fslogin),
		},
		'where' => {
			'username' => $email,
		},
	);
}

sub get_target_id
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $trec = undef;
	if (defined $param->{'email_id'})
	{
		$trec = Note::Row::find_create('ring_target' => {
			'target_type' => 'email',
			'email_id' => $param->{'email_id'},
			'user_id' => $uid,
		});
	}
	elsif (defined $param->{'did_id'})
	{
		$trec = Note::Row::find_create('ring_target' => {
			'target_type' => 'did',
			'did_id' => $param->{'did_id'},
			'user_id' => $uid,
		});
	}
	elsif (defined $param->{'domain_id'})
	{
		$trec = Note::Row::find_create('ring_target' => {
			'target_type' => 'domain',
			'domain_id' => $param->{'domain_id'},
			'user_id' => $uid,
		});
	}
	return undef unless (defined $trec);
	return $trec->id();
}

sub add_phone
{
	my ($obj, $param) = get_param(@_);
	my $tbl = Note::Row::table('ring_phone');
	my $sr = new String::Random();
	my $login;
	do {
		$login = $sr->randregex('[a-z0-9]{7}');
	} while ($tbl->count(
		'login' => $login,
	));
	my $rc = undef;
	eval {
		$rc = Note::Row::create('ring_phone' => {
			'login' => $login,
			'password' => $sr->randregex('[a-z0-9]{12}'),
			'user_id' => $obj->id(),
		});
	};
	if ($@)
	{
		if ($@ =~ /duplicate/i)
		{
			return $obj->add_phone($param);
		}
		die($@);
	}
	return $rc;
}

sub get_phones
{
	my ($obj, $param) = get_param(@_);
	my $tbl = Note::Row::table('ring_phone');
	return $tbl->get(
		'select' => ['id', 'login', 'password'],
		'where' => {'user_id' => $obj->id()},
		'order' => 'id asc',
	);
}

# static method
sub onboard_email
{
	my (undef, $param) = get_param(undef, @_);
	my $email = $param->{'to'};
	my $from = $param->{'from'};
	my $res = {};
	my $userrc = new Note::Row(
		'ring_user' => {
			'login' => $email,
		},
	);
	if ($userrc->id())
	{
		$res->{'user'} = 1;
		return $res;
	}
	else
	{
		my $obrc = new Note::Row(
			'ring_onboard_email' => {
				'email' => $email,
			},
			'select' => ['ts', 'unsub'],
		);
		if ($obrc->id())
		{
			if ($obrc->data('unsub'))
			{
				return $res;
			}
			my $ts = str2time($obrc->data('ts'));
			my $today = strftime("%F", localtime());
			my $tsdate = strftime("%F", localtime($ts));
			if ($today eq $tsdate)
			{
				return $res;
			}
			$obrc->update({
				'ts' => strftime("%F %T", localtime()),
			});
		}
		else
		{
			Note::Row::create('ring_onboard_email', {
				'email' => $email,
				'ts' => strftime("%F %T", localtime()),
			});
		}
		my $rgm = 'RingMail <ringmail@ringmail.com>';
		my $tmpl = new Note::Template(
			'root' => $main::note_config->{'root'}. '/app/ringmail/template',
		);
		my $txt = $tmpl->template('email/onboard.txt', {
			'from' => $from,
		});
		my $html = $tmpl->template('email/onboard.html', {
			'from' => $from,
		});
		my $msg = new MIME::Lite(
			'To' => $email,
			'From' => $rgm,
			'Subject' => "$from tried to call you on RingMail. You are invited to join RingMail for free!",
			'Type' => 'multipart/alternative',
			'Data' => $txt,
		);
		my $msgtxt = new MIME::Lite(
			'Type' => 'text/plain; charset="iso-8859-1"',
			'Data' => $txt,
		);
		my $msghtml = new MIME::Lite(
			'Type' => 'text/html; charset="iso-8859-1"',
			'Data' => $html,
		);
		$msg->attach($msgtxt);
		$msg->attach($msghtml);
		eval {
			$msg->send(
				'smtp' => 'localhost',
				'Timeout' => 10,
			);
		};
		if ($@)
		{
			::_errorlog('Email Error:', $@);
		}
		$res->{'sent'} = 1;
	}
	return $res;
}

sub add_contact
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact'};
	my $uid = $obj->id();
	my $ctrec = Note::Row::create('ring_contact' => {
		'user_id' => $uid,
		'apple_id' => $ct->{'id'},
		'first_name' => $ct->{'first_name'},
		'last_name' => $ct->{'last_name'},
		'organization' => $ct->{'organization'},
		'ts_updated' => strftime("%F %T", gmtime($ct->{'ts_updated'})),
	});
	my $item = new Ring::Item();
	foreach my $em (@{$ct->{'email'}})
	{
		if (Email::Valid->address($em))
		{
			my $erec = $item->item(
				'type' => 'email',
				'email' => $em,
			);
			Note::Row::find_create('ring_contact_email' => {
				'contact_id' => $ctrec->id(),
				'email_id' => $erec->id(),
			}, {
				'user_id' => $uid,
			});
		}
		else
		{
			::_errorlog("Skipped invalid email: '$em' for user_id: $uid");
		}
	}
	foreach my $ph (@{$ct->{'phone'}})
	{
		$ph =~ s/\D//g;
		if (length($ph) == 11)
		{
			$ph =~ s/^1//;
		}
		if (length($ph) == 10)
		{
			my $drec = $item->item(
				'type' => 'did',
				'did_number' => $ph,
			);
			Note::Row::find_create('ring_contact_phone' => {
				'contact_id' => $ctrec->id(),
				'did_id' => $drec->id(),
			}, {
				'user_id' => $uid,
			});
		}
		else
		{
			::_errorlog("Skipped invalid phone: '$ph' for user_id: $uid");
		}
	}
}

sub update_contact
{
	my ($obj, $param) = get_param(@_);
	my $ct = $param->{'contact'};
	my $uid = $obj->id();
	my $ctrec = new Note::Row('ring_contact' => {
		'user_id' => $uid,
		'apple_id' => $ct->{'id'},
	});
	if ($ctrec->id())
	{
		$ctrec->update({
			'first_name' => $ct->{'first_name'},
			'last_name' => $ct->{'last_name'},
			'organization' => $ct->{'organization'},
			'ts_updated' => strftime("%F %T", gmtime($ct->{'ts_updated'})),
		});
		my $item = new Ring::Item();
		sqltable('ring_contact_email')->delete('where' => {'contact_id' => $ctrec->id()});
		foreach my $em (@{$ct->{'email'}})
		{
			if (Email::Valid->address($em))
			{
				my $erec = $item->item(
					'type' => 'email',
					'email' => $em,
				);
				Note::Row::find_create('ring_contact_email' => {
					'contact_id' => $ctrec->id(),
					'email_id' => $erec->id(),
				}, {
					'user_id' => $uid,
				});
			}
			else
			{
				::_errorlog("Skipped invalid email: '$em' for user_id: $uid");
			}
		}
		sqltable('ring_contact_phone')->delete('where' => {'contact_id' => $ctrec->id()});
		foreach my $ph (@{$ct->{'phone'}})
		{
			$ph =~ s/\D//g;
			if (length($ph) == 11)
			{
				$ph =~ s/^1//;
			}
			if (length($ph) == 10)
			{
				my $drec = $item->item(
					'type' => 'did',
					'did_number' => $ph,
				);
				Note::Row::find_create('ring_contact_phone' => {
					'contact_id' => $ctrec->id(),
					'did_id' => $drec->id(),
				}, {
					'user_id' => $uid,
				});
			}
			else
			{
				::_errorlog("Skipped invalid phone: '$ph' for user_id: $uid");
			}
		}
	}
	else
	{
		::_errorlog("Unable to update contact apple_id: '$ct->{'id'}' for user_id: $uid");
	}
}

sub delete_contact
{
	my ($obj, $param) = get_param(@_);
	my $appleid = $param->{'apple_id'};
	my $uid = $obj->id();
	my $ctrec = new Note::Row('ring_contact' => {
		'user_id' => $uid,
		'apple_id' => $appleid,
	});
	if ($ctrec->id())
	{
		sqltable('ring_contact_email')->delete('where' => {'contact_id' => $ctrec->id()});
		sqltable('ring_contact_phone')->delete('where' => {'contact_id' => $ctrec->id()});
		$ctrec->delete();
	}
	else
	{
		::_errorlog("Unable to delete contact apple_id: '$appleid' for user_id: $uid");
	}
}

sub get_contacts_hash
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $q = sqltable('ring_contact')->get(
		'select' => ['id', 'apple_id', 'ts_updated'],
		'where' => {
			'user_id' => $uid,
			((defined $param->{'apple_id'}) ? ('apple_id' => $param->{'apple_id'}) : ()),
		},
	);
	my %hrec = ();
	foreach my $r (@$q)
	{
		$r->{'ts_updated'} = str2time("$r->{'ts_updated'}Z");
		$hrec{$r->{'apple_id'}} = $r;
	}
	return \%hrec;
}

1;

