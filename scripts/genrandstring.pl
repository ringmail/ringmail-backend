#!/usr/bin/perl

use Bytes::Random::Secure qw(random_string_from);

use constant NUM_BYTES => 64;
use constant CHARACTERS => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

my $randString = random_string_from(CHARACTERS, NUM_BYTES);
print $randString;