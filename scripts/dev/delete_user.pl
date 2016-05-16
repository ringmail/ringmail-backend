#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use POSIX 'strftime';
use Digest::SHA 'sha256_hex';
use URI::Escape 'uri_escape';
use Note::Base;

my $user = new Note::Row('ring_user' => {
	'login' => $ARGV[0],
});

if (defined $user->id())
{
	my $uid = $user->id();
	::log("Found User ID: $uid");
	# ring_contact_email
	sqltable('ring_contact')->delete(
		'table' => 'ring_contact c, ring_contact_email e',
		'delete' => ['e.*'],
		'join' => [
			'c.id=e.contact_id',
		],
		'where' => {
			'c.user_id' => $uid,
		},
	);
	# ring_contact_phone
	sqltable('ring_contact')->delete(
		'table' => 'ring_contact c, ring_contact_phone p',
		'delete' => ['p.*'],
		'join' => [
			'c.id=p.contact_id',
		],
		'where' => {
			'c.user_id' => $uid,
		},
	);
	# ring_contact
	sqltable('ring_contact')->delete('where' => { 'user_id' => $uid });
	# ring_device
	sqltable('ring_device')->delete('where' => { 'user_id' => $uid });
	# ring_hashtag
	sqltable('ring_hashtag')->delete('where' => { 'user_id' => $uid });
	# ring_person
	sqltable('ring_person')->delete(
		'delete' => 'p.*',
		'table' => 'ring_person p, ring_user u',
		'join' => 'u.person = p.id',
		'where' => { 'u.id' => $uid },
	);
	# ring_phone
	my $phs = sqltable('ring_phone')->get(
		'select' => ['login'],
		'where' => { 'user_id' => $uid },
	);
	my $kdb = $main::note_config->storage()->{'kam_1'};
	foreach my $p (@$phs)
	{
		$kdb->table('subscriber')->delete(
			'where' => { 'username' => $p->[0] },
		);
	}
	sqltable('ring_phone')->delete('where' => { 'user_id' => $uid });
	# ring_route
	sqltable('ring_route')->delete('where' => { 'user_id' => $uid });
	# ring_target_route
	sqltable('ring_target_route')->delete(
		'delete' => 'r.*',
		'table' => 'ring_target_route r, ring_target t',
		'join' => 'r.target_id = t.id',
		'where' => { 't.user_id' => $uid },
	);
	# ring_target
	sqltable('ring_target')->delete('where' => { 'user_id' => $uid });
	# ring_user_apns
	sqltable('ring_user_apns')->delete('where' => { 'user_id' => $uid });
	# ring_user_contact_sync
	sqltable('ring_user_contact_sync')->delete('where' => { 'user_id' => $uid });
	# ring_user_did
	sqltable('ring_user_did')->delete('where' => { 'user_id' => $uid });
	# ring_user_email
	sqltable('ring_user_email')->delete('where' => { 'user_id' => $uid });
	# ring_verify_did
	sqltable('ring_verify_did')->delete('where' => { 'user_id' => $uid });
	# ring_verify_email
	sqltable('ring_verify_email')->delete('where' => { 'user_id' => $uid });

	my $escuser = uri_escape(lc($user->data('login')), q{"#\%/:<>?\@^`\[\]});
	my $chdb = $main::note_config->storage()->{'ejd_1'};
	$chdb->table('users')->delete(
		'where' => {
			'username' => $escuser,
		},
	);

	sqltable('ring_user')->delete('where' => { 'id' => $uid });
}
else
{
	print "User Not Found\n";
	exit(1);
}

