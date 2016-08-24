#!/usr/bin/perl -wT 

use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use Note::Base;
use strict;
use warnings;

sqltable('ring_cart')->delete(
    delete => [ qw{ ring_hashtag ring_cart }, ],
    table  => 'ring_hashtag, ring_cart',
    join   => [ 'ring_cart.hashtag_id = ring_hashtag.id', 'ring_cart.user_id = ring_hashtag.user_id', ],
    where  => {
        'ring_cart.transaction_id' => undef,
        'ring_cart.ts'             => [ '<', 'NOW() - INTERVAL 2 HOUR', ],
    },
);

my $carts = sqltable('ring_cart')->get(
    select => 'ring_cart.id',
    table  => ring_cart => join_left => [ [ ring_hashtag => 'ring_hashtag.id = ring_cart.hashtag_id', ], ],
    where => { 'ring_hashtag.id' => undef, },
);

for my $cart ( @{$carts} ) {

    sqltable('ring_cart')->delete( delete => ring_cart => where => { 'ring_cart.id' => $cart->{id}, }, );

}
