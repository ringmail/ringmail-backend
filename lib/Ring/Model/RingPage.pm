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

sub validate_ringpage {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $ringpage = $param->{ringpage};
    if ( $ringpage =~ qr{\A [\w\s]+ \z}xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $ringpage = $param->{ringpage};
    unless ( $obj->validate_ringpage( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    return sqltable('ring_page')->count( ringpage => $ringpage, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    my $ringpage     = $param->{ringpage};
    my $ringlink_url = $param->{ringlink_url};
    my $ringlink     = $param->{ringlink};
    my $template_id  = $param->{template_id};
    unless ( $obj->validate_ringpage( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    my $uid = $param->{'user_id'};
    my $trec;

    try { $trec = Note::Row::create( ring_page => { ringpage => $ringpage, ringlink_url => $ringlink_url, ringlink => $ringlink, template_id => $template_id, user_id => $uid, } ); }
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
        ring_page => {
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
        ring_page => {
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

sub list {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_page')->get(
        select => [ 'p.id',        'p.ringpage', 't.path', ],
        table  => [ 'ring_page p', 'ring_template t', ],
        join   => [ 'p.template_id = t.id', ],
        where => { 'p.user_id' => $param->{user_id}, },
    );
    return $q;
}

sub retrieve {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_page')->get(
        select => [ 'p.id',        'p.ringlink_url', 'p.ringlink', ],
        table  => [ 'ring_page p', 'ring_template t', ],
        join   => [ 'p.template_id = t.id', ],
        where => { 'p.user_id' => $param->{user_id}, 'p.id' => $param->{id}, },
    );

    return $q->[0];
}

1;
