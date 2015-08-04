#!/usr/bin/perl

use Data::Dumper;
use Authen::Passphrase;
use Authen::Passphrase::SaltedSHA512;

my $pw = new Authen::Passphrase::SaltedSHA512(
	'passphrase' => 'test',
);

print Dumper({
	'hash_hex' => $pw->hash_hex(),
	'salt_hex' => $pw->salt_hex(),
});

print Dumper({
	'hash_hex' => $pw->hash_hex(),
	'salt_hex' => $pw->salt_hex(),
});



