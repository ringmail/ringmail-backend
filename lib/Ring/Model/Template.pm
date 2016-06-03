package Ring::Model::Template;

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

sub validate_template {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = $param->{template};
    if ( $template =~ /\A \w+ \z/xms ) {
        return 1;
    }
    return 0;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = $param->{template};
    if ( not $obj->validate_template( template => $template, ) ) {
        croak(qq|Invalid template '$template'|);
    }
    return sqltable('ring_template')->count( template => $template, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $template = $param->{template};
    my $path     = $param->{path};
    my $uid      = $param->{user_id};

    if ( not $obj->validate_template( template => $template, ) ) {
        croak(qq|Invalid template '$template'|);
    }

    my $trec;

    try {
        $trec = Note::Row::create(
            ring_template => {
                template => $template,
                path     => $path,
                user_id  => $uid,
            },
        );
    }
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
        ring_template => {
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

sub list {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $uid = $param->{'user_id'};
    my $q = sqltable('ring_template')->get( 'select' => [ qw{ id template path }, ], );
    return $q;
}

1;
