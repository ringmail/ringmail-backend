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
    my $ringpage = $param->{ringpage};
    if ( $ringpage =~ qr{\A \w+ \z}xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $ringpage = $param->{ringpage};
    unless ( $obj->validate_page( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    return sqltable('ringpage')->count( ringpage => $ringpage, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    my $ringpage    = $param->{ringpage};
    my $ringurl     = $param->{ringurl};
    my $link        = $param->{link};
    my $template_id = $param->{template_id};
    unless ( $obj->validate_page( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    my $uid = $param->{'user_id'};
    my $trec;

    try { $trec = Note::Row::create( ringpage => { ringpage => $ringpage, ringurl => $ringurl, link => $link, template_id => $template_id, user_id => $uid, } ); }
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
        ringpage => {
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
        ringpage => {
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
    my $q = sqltable('ringpage')->get(
        select => [ 'p.id',       'p.ringpage', 't.path', ],
        table  => [ 'ringpage p', 'template t', ],
        join   => [ 'p.template_id = t.id', ],
        where => { 'p.user_id' => $param->{user_id}, },
    );
    return $q;
}

1;
