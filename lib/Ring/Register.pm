package Ring::Register;
use strict;
use warnings;

use Moose;
use Try::Tiny;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Math::Random::Secure;
use Authen::Passphrase;
use Authen::Passphrase::SaltedSHA512;
use POSIX 'strftime';
use String::Random;
use MIME::Lite;
use Digest::MD5 'md5_hex';
use URI::Escape;
use Date::Parse 'str2time';
use Math::Random::Secure 'rand';
use String::Random 'random_regex';

use Note::SQL::Table 'sqltable', 'transaction';
use Note::Param;
use Note::Row;
use Note::Check;
use Note::XML 'xml';
use Note::Template;
use Note::Account;

use Ring::Item;
use Ring::Valid 'validate_phone', 'validate_email', 'split_phone';
use Ring::Exceptions 'throw_duplicate';

no warnings qw(uninitialized);

use vars qw();

# params:
#  email
#  phone
#  first_name
#  last_name
#  password
sub validate_input
{
	my ($obj, $param) = get_param(@_);
	unless (validate_email($param->{'email'}))
	{
		InvalidUserInput->throw('message' => 'Invalid email');
	}
	unless (validate_phone($param->{'phone'}))
	{
		InvalidUserInput->throw('message' => 'Invalid phone');
	}
	my $check_name = new Note::Check(
		'type' => 'regex',
		'chars' => 'A-Za-z0-9.- ',
	);
	unless ($check_name->valid(\$param->{'first_name'}))
	{
		InvalidUserInput->throw('message' => 'Invalid first name');
	}
	unless ($check_name->valid(\$param->{'last_name'}))
	{
		InvalidUserInput->throw('message' => 'Invalid last name');
	}
	unless (length($param->{'password'}) >= 4)
	{
		InvalidUserInput->throw('message' => 'Password too short');
	}
	return 1;
}

# params:
#  email
#  phone
sub check_duplicate
{
	my ($obj, $param) = get_param(@_);
	my $em = $param->{'email'};
	my $phone = $param->{'phone'};
	if (sqltable('ring_user')->count('login' => $em))
	{
		DuplicateData->throw('message' => 'Duplicate email');
	}
	my ($did_code, $did_number) = split_phone($phone);
	my $c = sqltable('ring_did')->get(
		'array' => 1,
		'result' => 1,
		'table' => 'ring_did d, ring_user_did ud',
		'select' => 'count(ud.id)',
		'join' => 'd.id=ud.did_id',
		'where' => {
			'did_code' => $did_code,
			'did_number' => $did_number,
		},
	);
	if ($c)
	{
		DuplicateData->throw('message' => 'Duplicate phone');
	}
	return 1;
}

sub create_user
{
	my ($obj, $param) = get_param(@_);
	# create the user
	open (S, '-|', '/home/note/app/ringmail/scripts/gensalt.pl');
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
	my $urec = undef;
	my $user = undef;
	my $sr = new String::Random();
	my $chatpass = $sr->randregex('[a-z0-9]{12}');
	transaction(sub {
		# create user login 
		throw_duplicate(sub {
			$urec = Note::Row::create('ring_user' => {
				'active' => 1,
				'login' => lc($param->{'email'}),
				'password_fs' => '', # deprecated
				'password_hash' => $hash,
				'password_salt' => $salt,
				'password_chat' => $chatpass,
				'person' => 0, # update next
				'verified' => 0,
			})
		}, 'Duplicate login');

		# create proxy login
		my $chdb = $main::note_config->storage()->{'ejd_1'};
		my $escuser = uri_escape(lc($param->{'email'}), q{"#\%/:<>?\@^`\[\]});
		throw_duplicate(sub {
			$chdb->table('users')->set(
				'insert' => {
					'username' => $escuser,
					'password' => $chatpass,
					'created_at' => strftime("%F %T", localtime()),
				},
			);
		}, 'Duplicate proxy username');

		# setup user
		my $item = new Ring::Item();
		my $erec = $item->item(
			'type' => 'email',
			'email' => $param->{'email'},
		);
		Note::Row::create('ring_user_email' => {
			'email_id' => $erec->id(),
			'user_id' => $urec->id(),
			'primary_email' => 1,
		});
		$user = new Ring::User($urec->id());
		my $tid = $user->get_target_id(
			'email_id' => $erec->id(),
		);

		# setup phone
		my $phs = $user->get_phones();
		unless (scalar @$phs)
		{
			$user->add_phone();
		}
	});
	unless ($param->{'skip_verify'})
	{
		$user->verify_email_send(
			'email' => $param->{'email'},
		);
	}
	return $urec->id();
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
	);
	$rc->update({
		'reset_hash' => $code,
		'ts' => strftime("%F %T", localtime()),
	});
	my $from = 'RingMail <ringmail@ringmail.com>';
	my $wdom = $main::app_config->{'www_domain'};
	my $link = 'https://'. $wdom. '/reset?code='. $code;
	my $tmpl = new Note::Template(
		'root' => $main::note_config->{'root'}. '/app/ringmail/template',
	);
	my $txt = $tmpl->apply('email/reset_pass.txt', {
		'link' => $link,
		'email' => $param->{'email'},
	});
	my $html = $tmpl->apply('email/reset_pass.html', {
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
	my $wdom = $main::app_config->{'www_domain'};
	my $from = 'RingMail <ringmail@ringmail.com>';
	my $link = 'https://'. $wdom. '/verify?code='. $code;
	my $tmpl = new Note::Template(
		'root' => $main::note_config->{'root'}. '/app/ringmail/template',
	);
	my $txt = $tmpl->apply('email/verify.txt', {
		'www_domain' => $wdom,
		'link' => $link,
	});
	my $html = $tmpl->apply('email/verify.html', {
		'www_domain' => $wdom,
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

1;

