package Ring::Model::Template;

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

sub validate_template {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = $param->{template};
    if ( $template =~ /^[a-z0-9_]+$/xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = $param->{template};
    unless ( $obj->validate_template( template => $template, ) ) {
        croak(qq|Invalid template '$template'|);
    }
    return sqltable('template')->count( template => $template, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = lc( $param->{template} );
    unless ( $obj->validate_template( template => $template, ) ) {
        croak(qq|Invalid template '$template'|);
    }
    my $uid = $param->{'user_id'};
    my $trec;

    try { $trec = Note::Row::create( template => { template => $template, user_id => $uid, } ); }
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
        template => {
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
        template => {
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

sub get_user_templates {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $uid = $param->{'user_id'};
    my $q   = sqltable('template')->get(
        'select' => [ qw{ id template }, ],
        'where'  => { 'user_id' => $uid, },
    );
    return $q;
}

1;
