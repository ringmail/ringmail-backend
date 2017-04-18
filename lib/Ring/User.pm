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
use Ring::Exceptions;
use Ring::Twilio;

no warnings qw(uninitialized);

has 'id' => (
	'is' => 'rw',
	'isa' => 'Int',
);

has 'row' => (
	'is' => 'rw',
	'isa' => 'Note::Row',
	'lazy' => 1,
	'default' => sub {
		my $obj = shift;
		return new Note::Row('ring_user' => {'id' => $obj->id()});
	},
);

has email => (
	'is' => 'rw',
	'isa' => 'Str',
	'lazy' => 1,
	'default' => sub {
		my $obj = shift;
		return  $obj->row()->data('login');
	},
);

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
		::errorlog('Email Error:', $@);
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
	transaction(sub {
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
		$obj->get_target_id(
			'email_id' => $rec->data('email_id'),
		);
	});
	return 1;
}

# static method
sub lookup_user_phone
{
	my (undef, $param) = get_param(undef, @_);
	my $phone = $param->{'phone'};
	unless (validate_phone($param->{'phone'}))
	{
		InvalidUserInput->throw('message' => 'Invalid phone');
	}
	my ($did_code, $did_number) = split_phone($param->{'phone'});
	my $item = new Ring::Item();
	my $drec = $item->item(
		'type' => 'did',
		'did_number' => $did_number,
		'did_code' => $did_code,
		'no_create' => 1,
	);
	if (defined $drec)
	{
		my $rc = new Note::Row(
			'ring_user_did' => {
				'did_id' => $drec->id(),
			},
		);
		if ($rc->id())
		{
			return new Ring::User($rc->data('user_id'));
		}
		else
		{
			InvalidUserInput->throw('message' => 'Unknown user for phone number');
		}
	}
	else
	{
		InvalidUserInput->throw('message' => 'Unknown phone number');
	}
}

sub verify_phone_send
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $phone = $param->{'phone'};
	unless (validate_phone($param->{'phone'}))
	{
		InvalidUserInput->throw('message' => 'Invalid phone');
	}
	my ($did_code, $did_number) = split_phone($param->{'phone'});
	my $item = new Ring::Item();
	my $drec = $item->item(
		'type' => 'did',
		'did_number' => $did_number,
		'did_code' => $did_code,
		'no_create' => 1,
	);
	if (defined $drec)
	{
		my $rc = new Note::Row(
			'ring_verify_did' => {
				'did_id' => $drec->id(),
				'user_id' => $uid,
			},
		);
		if ($rc->id())
		{
			if ($rc->data('verified'))
			{
				DuplicateData->throw('message' => 'Phone number already verified');
			}
			else
			{
				my $msg = 'RingMail Code: '. $rc->data('verify_code');
				my $tw = new Ring::Twilio();
				my $reply = $tw->send_sms(
					'to' => $phone,
					'from' => '+14243260287',
					'body' => $msg,
				);
				unless ($reply->{'ok'})
				{
					::errorlog('Send SMS Error', $reply);
					FatalError->throw('message' => 'Unable to send SMS');
				}
			}
		}
		else
		{
			InvalidUserInput->throw('message' => 'Phone number not set to be verified for user');
		}
	}
	else
	{
		InvalidUserInput->throw('message' => 'Unknown phone number');
	}
}

sub verify_phone
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $phone = $param->{'phone'};
	unless (validate_phone($param->{'phone'}))
	{
		InvalidUserInput->throw('message' => 'Invalid phone');
	}
	my ($did_code, $did_number) = split_phone($param->{'phone'});
	my $item = new Ring::Item();
	my $drec = $item->item(
		'type' => 'did',
		'did_number' => $did_number,
		'did_code' => $did_code,
	);
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
			'd.id' => $drec->id(),
		},
		'order' => 'd.id asc',
	);
	unless (scalar(@$q) == 1)
	{
		InvalidUserInput->throw('message' => 'Phone number not set to be verified for user');
	}
	if ($q->[0]->{'verified_1'} || $q->[0]->{'verified_2'})
	{
		DuplicateData->throw('message' => 'Already verified');
	}
	my $ok = 0;
	transaction(sub {
		my $did = $q->[0]->{'did_id'};
		my $ud = new Note::Row(
			'ring_user_did' => {
				'user_id' => $uid,
				'did_id' => $did,
			},
		);
		unless ($ud->{'id'})
		{
			InvalidUserInput->throw('message' => 'Phone number not associated with user');
		}
		my $vrd = new Note::Row(
			'ring_verify_did' => {
				'user_id' => $uid,
				'did_id' => $did,
			},
		);
		unless ($vrd->{'id'})
		{
			InvalidUserInput->throw('message' => 'Phone number not set to be verified for user');
		}
		sqltable('ring_verify_did')->do(
			'sql' => 'UPDATE ring_verify_did SET tries = tries + 1 WHERE id = ?',
			'bind' => [$vrd->id()],
		);
		my $code = $q->[0]->{'verify_code'};
		if ($code eq $param->{'verify_code'})
		{
			$ud->update({
				'verified' => 1,
			});
			$vrd->update({
				'verified' => 1,
				'ts_verified' => strftime("%F %T", localtime()),
			});
			my $tid = $obj->get_target_id(
				'did_id' => $did,
			);
			$obj->set_target_route(
				'target_id' => $tid,
				'endpoint_type' => 'app',
				'endpoint_id' => undef, # app
			);
			$ok = 1;
		}
	});
	unless ($ok)
	{
		InvalidUserInput->throw('message' => 'Bad verification code');
	}
	return 1;
}

sub check_password
{
	my ($obj, $param) = get_param(@_);
	my $auth = new Authen::Passphrase::SaltedSHA512(
		'salt_hex' => $param->{'salt'},
		'hash_hex' => $param->{'hash'},
	);
	return 1 if ($auth->match($param->{'password'}));
	return 0;
}

sub password_change
{
	my ($obj, $param) = get_param(@_);
	my $pass = $param->{'password'};
	open (S, '-|', '/home/note/app/ringmail/scripts/gensalt.pl');
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
	my $urec = new Note::Row('ring_user' => {'id' => $obj->id()});
	$urec->update({
		'password_fs' => '', # deprecated
		'password_hash' => $hash,
		'password_salt' => $salt,
	});
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

sub set_target_route
{
	my ($obj, $param) = get_param(@_);
	my $uid = $obj->id();
	my $rt = $param->{'endpoint_type'};
	my $epid = $param->{'endpoint_id'}; # endpoint_type 'app' does not have an endpoint_id
	my $tgt = $param->{'target_id'};
	sqltable('ring_target_route')->delete(
		'where' => {'target_id' => $tgt},
	);
	if ($rt eq 'did')
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
	}
}

sub add_phone
{
	my ($obj, $param) = get_param(@_);
	my $tbl = Note::Row::table('ring_phone');
	my $sr = new String::Random();
	my $login;
	do {
		$login = $sr->randregex('[a-z0-9]{8}');
	} while ($tbl->count(
		'login' => $login,
	));
	my $rc = undef;
	my $pass = $sr->randregex('[a-z0-9]{12}');
	my $fsdb = $main::note_config->storage()->{'kam_1'};
	my $fsdomain = $main::app_config->{'sip_domain'};
	#my $fslogin = $login. ':'. $fsdomain. ':'. $pass;
	eval {
		$rc = Note::Row::create('ring_phone' => {
			'login' => $login,
			'password' => $pass,
			'user_id' => $obj->id(),
		});
		$fsdb->table('subscriber')->set(
			'insert' => {
				'username' => $login,
				'domain' => $fsdomain,
				'password' => $pass,
				#'ha1' => md5_hex($fslogin),
			},
		);
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
		my $txt = $tmpl->apply('email/onboard.txt', {
			'from' => $from,
		});
		my $html = $tmpl->apply('email/onboard.html', {
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
		'ts_created' => strftime("%F %T", gmtime($ct->{'ts_created'})),
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

# static method: login
sub login
{
	my (undef, $param) = get_param(undef, @_);

    my $login = $param->{'login'};
        
    my $rc = new Note::Row(
		'ring_user' => {
			'login' => $login,
		},
		{
			'select' => [qw/password_salt password_hash/],
		},
	);
	if ($rc->id())
	{
		my $user = new Ring::User($rc->id());

		if ($user->check_password(
			'salt' => $rc->data('password_salt'),
			'hash' => $rc->data('password_hash'),
			'password' => $param->{'password'},
		)) {
			return $user;
		}
		else
		{
			return undef;
		}
	}
	else
	{
		return undef;
	}
}

sub aws_user_id {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $user_id       = $self->id();
    my $user_row_data = $self->row()->data();

    my $aws_user_id = $user_row_data->{aws_user_id};

    if ( defined $aws_user_id and length $aws_user_id > 0 ) {

        return $aws_user_id;
    }

    else {

        my $ring_user = Note::Row::table('ring_user');

        my $random_string;

        do {

            $random_string = random_regex '[A-Za-z0-9]{32}';

        } while ( $ring_user->count( aws_user_id => $random_string, ) > 0 );

        my $user_row = Note::Row->new( ring_user => $user_id, );
        $user_row->update( { aws_user_id => $random_string, }, );

        return $random_string;

    }

    return;
}

1;
