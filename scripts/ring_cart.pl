#!/usr/bin/perl -wT 

use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use Note::Base;
use strict;
use warnings;

sqltable('ring_cart')->delete(
    delete => [ 'rh', ],
    table  => 'ring_hashtag AS rh, ring_cart AS rc',
    join   => [ 'rc.hashtag_id = rh.id', 'rc.user_id = rh.user_id', ],
    where  => {
        'rc.transaction_id' => undef,
        'rc.ts'             => [ '<', 'NOW() - INTERVAL 2 HOUR', ],
    },
);
