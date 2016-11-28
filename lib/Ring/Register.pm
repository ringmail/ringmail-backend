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

use Ring::Valid 'validate_phone', 'validate_email', 'split_phone';
use Ring::Exceptions 'throw_duplicate';
use Ring::Item;
use Ring::User;

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
	my $smscode = $sr->randregex('[0-9]{4}');
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
				'verified' => ($param->{'verified'}) ? 1 : 0,
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

		# setup did
		if (defined($param->{'phone'}))
		{
			my ($did_code, $did_number) = split_phone($param->{'phone'});
			my $drec = $item->item(
				'type' => 'did',
				'did_number' => $did_number,
				'did_code' => $did_code,
			);
			throw_duplicate(sub {
				Note::Row::create('ring_user_did' => {
					'did_id' => $drec->id(),
					'ts_added' => strftime("%F %T", localtime()),
					'user_id' => $urec->id(),
					'verified' => ($param->{'verified'}) ? 1 : 0,
				});
			}, 'Duplicate user phone');
			unless ($param->{'skip_verify_phone'})
			{
				sqltable('ring_verify_did')->delete(
					'where' => {
						'did_id' => $drec->id(),
						'user_id' => $urec->id(),
					},
				);
				Note::Row::create('ring_verify_did' => {
					'did_id' => $drec->id(),
					'ts_added' => strftime("%F %T", localtime()),
					'user_id' => $urec->id(),
					'verified' => 0,
					'verify_code' => $smscode,
					'tries' => 0,
				});
			}
		}
		
		# setup person
		if (defined $param->{'first_name'} && defined $param->{'last_name'})
		{
			my $rc = Note::Row::create('ring_person', {
				'first_name' => $param->{'first_name'},
				'last_name' => $param->{'last_name'},
			});
			$urec->update({
				'person' => $rc->id(),
			});
		}

		# setup phone proxy login
		my $phs = $user->get_phones();
		unless (scalar @$phs)
		{
			$user->add_phone();
		}

		# setup contacts
		if (defined $param->{'contacts'}) # create contact list
		{
			my $maxts = 0;
			foreach my $ct (@{$param->{'contacts'}})
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
				'user_id' => $urec->id(),
				'ts_updated' => ($maxts) ? strftime("%F %T", gmtime($maxts)) : undef,
				'item_count' => scalar(@{$param->{'contacts'}}),
			});
		}

		# begin verifications
		unless ($param->{'skip_verify_email'})
		{
			$user->verify_email_send(
				'email' => $param->{'email'},
			);
		}
	});
	return $urec->id();
}

1;

