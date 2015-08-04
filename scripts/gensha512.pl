#!/usr/bin/perl

use Data::Dumper;
use Authen::Passphrase::SaltedDigest;

my $pw = new Authen::Passphrase::SaltedDigest(
	'algorithm' => 'SHA-512',
	'passphrase' => 'test',
	'salt_hex' => `perl gensalt.pl`,
);

print Dumper({
	'hash_hex' => $pw->hash_hex(),
	'salt_hex' => $pw->salt_hex(),
});

