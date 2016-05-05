package Ring::Model::Hashtag;

use strict;
use warnings;

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use POSIX 'strftime';
use Regexp::Common 'URI';

use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::User;

sub validate_tag {
    my ( $obj, $param ) = get_param(@_);
    my $tag = $param->{'tag'};
    if ( $tag =~ /^[a-z0-9_]+$/ ) {
        return 1;
    }
    return 0;
}

sub validate_target {
    my ( $obj, $param ) = get_param(@_);
    my $target = $param->{'target'};
    if ( $target =~ /^$RE{URI}{HTTP}{-scheme=>qr|https?|}$/ ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( $obj, $param ) = get_param(@_);
    my $tag = lc( $param->{'tag'} );
    unless ( $obj->validate_tag( 'tag' => $tag, ) ) {
        die(qq|Invalid hashtag: '$tag'|);
    }
    return sqltable('ring_hashtag')->count( 'hashtag' => $tag, );
}

sub create {
    my ( $obj, $param ) = get_param(@_);
    my $tag = lc( $param->{'tag'} );
    unless ( $obj->validate_tag( 'tag' => $tag, ) ) {
        die(qq|Invalid hashtag: '$tag'|);
    }
    my $uid     = $param->{'user_id'};
    my $url     = $param->{'target_url'};
    my $expires = $param->{'expires'};
    my $trec;
    eval { $trec = Note::Row::create( 'ring_hashtag', { 'hashtag' => $tag, 'user_id' => $uid, 'target_url' => $url, 'ts_expires' => $expires, } ); };
    if ($@) {
        my $err = $@;
        if ( $err =~ /Duplicate/ ) {
            return undef;
        }
        else {
            die($err);
        }
    }
    return $trec;
}

sub delete {
    my ( $obj, $param ) = get_param(@_);
    my $rc = new Note::Row(
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
    my ( $obj, $param ) = get_param(@_);
    my $rc = new Note::Row(
        'ring_hashtag' => {
            'user_id' => $param->{'user_id'},
            'id'      => $param->{'id'},
        },
    );
    if ( $rc->id() ) {
        $rc->update( { 'target_url' => $param->{'target'}, } );
        return 1;
    }
    else {
        return 0;
    }
}

sub get_user_hashtags {
    my ( $obj, $param ) = get_param(@_);
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

