#!/usr/bin/perl

use Bytes::Random::Secure qw(random_bytes_hex);

use constant NUM_BYTES => 64;
my $salt = random_bytes_hex(NUM_BYTES);
print $salt;

