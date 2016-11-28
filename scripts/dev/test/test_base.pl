#!/usr/bin/perl
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use strict;
use warnings;

use Note::Base 'ringmail';

my $ct = sqltable('ring_user')->count();

::log($ct);

::log($::app_config);

print "All Done!\n";
