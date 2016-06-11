package Ring::Model::Hashtag;

use strict;
use warnings;

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use Regexp::Common 'URI';
use Try::Tiny;
use Carp 'croak';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::User;

sub validate_tag {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $tag = $param->{'tag'};
    if ( $tag =~ m{ \A [a-z0-9_]+ \z }xms ) {
        return 1;
    }
    return 0;
}

sub validate_target {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $target = $param->{'target'};
    if ( $target =~ m{ \A $RE{URI}{HTTP}{-scheme=>qr|https?|} \z }xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $tag = lc( $param->{'tag'} );
    if ( not $obj->validate_tag( 'tag' => $tag, ) ) {
        croak(qq|Invalid hashtag: '$tag'|);
    }
    return sqltable('ring_hashtag')->count( 'hashtag' => $tag, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $tag = lc( $param->{'tag'} );
    if ( not $obj->validate_tag( 'tag' => $tag, ) ) {
        croak(qq|Invalid hashtag: '$tag'|);
    }
    my $uid     = $param->{'user_id'};
    my $url     = $param->{'target_url'};
    my $expires = $param->{'expires'};
    my $trec;

    ::log( $param, );

    try {
        $trec = Note::Row::create(
            'ring_hashtag',
            {

                category    => $param->{category},
                hashtag     => $tag,
                ringpage_id => $param->{ringpage_id},
                target_url  => $url,
                ts_expires  => $expires,
                user_id     => $uid,

            }
        );
    }
    catch {
        my $err = $_;
        if ( $err =~ m{ Duplicate }xms ) {
            return undef;
        }
        else {
            croak($err);
        }
    };

    return $trec;
}

sub delete {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $rc = Note::Row->new(
        'ring_hashtag' => {
            'user_id' => $param->{'user_id'},
            'id'      => $param->{'id'},
        },
    );
    if ( $rc->id() ) {
        $rc->delete();
        return 1;
    }
    else {
        return 0;
    }
}

sub update {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $rc = Note::Row->new(
        ring_hashtag => {
            user_id => $param->{user_id},
            id      => $param->{id},
        },
    );
    if ( $rc->id() ) {
        $rc->update(
            {

                ringpage_id => $param->{ringpage_id},
                target_url  => $param->{target},

            },
        );
        return 1;
    }
    else {
        return 0;
    }
}

sub get_user_hashtags {
    my ( @args, ) = @_;
    my ( $obj, $param, ) = get_param( @args, );
    my $uid = $param->{'user_id'};
    my $q   = sqltable('ring_hashtag')->get(
        'select' => [ 'id', 'hashtag', 'ts_expires as expires', 'target_url' ],
        'where' => { 'user_id' => $uid, },
        'order' => 'hashtag asc',

        #		'limit' => '10',
    );
    return $q;
}

1;
