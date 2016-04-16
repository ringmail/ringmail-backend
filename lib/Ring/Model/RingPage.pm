package Ring::Model::RingPage;

use strict;
use warnings;

use vars qw();

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

sub validate_page {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $page = $param->{page};
    if ( $page =~ /^[a-z0-9_]+$/xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $page = $param->{page};
    unless ( $obj->validate_page( page => $page, ) ) {
        croak(qq|Invalid page '$page'|);
    }
    return sqltable('page')->count( page => $page, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $page = lc( $param->{page} );
    unless ( $obj->validate_page( page => $page, ) ) {
        croak(qq|Invalid page '$page'|);
    }
    my $uid = $param->{'user_id'};
    my $trec;

    try { $trec = Note::Row::create( page => { page => $page, user_id => $uid, } ); }
    catch {
        my $err = $_;
        if ( $err =~ /Duplicate/xms ) {
            return undef;
        }
        else {
            croak $err;
        }
    };

    return $trec;
}

sub delete {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $rc = Note::Row->new(
        page => {
            user_id => $param->{user_id},
            id      => $param->{id},
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
    my ( $obj, $param ) = get_param( @args, );
    my $rc = Note::Row->new(
        page => {
            user_id => $param->{user_id},
            id      => $param->{id},
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

sub get_user_pages {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $uid = $param->{'user_id'};
    my $q   = sqltable('page')->get(
        'select' => [ qw{ id page }, ],
        'where'  => { 'user_id' => $uid, },
    );
    return $q;
}

1;
