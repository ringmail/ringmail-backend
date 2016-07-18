package Ring::Model::RingPage;

use Carp 'croak';
use constant::boolean;
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Ring::User;
use strict;
use Try::Tiny;
use warnings;

sub validate_ringpage {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $ringpage = $param->{ringpage};
    if ( $ringpage =~ qr{\A [\w\s]+ \z}xms ) {
        return TRUE;
    }
    return FALSE;
}

sub check_exists {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $ringpage = $param->{ringpage};
    if ( not $obj->validate_ringpage( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    return sqltable('ring_page')->count( ringpage => $ringpage, );
}

sub create {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    my $ringpage = $param->{ringpage};
    if ( not $obj->validate_ringpage( ringpage => $ringpage, ) ) {
        croak(qq|Invalid ringpage '$ringpage'|);
    }
    my $trec;

    try {
        $trec = Note::Row::create(
            ring_page => {

                fields   => $param->{fields},
                ringpage => $param->{ringpage},
                template => $param->{template_name},
                user_id  => $param->{user_id},

            }
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
        ring_page => {
            user_id => $param->{user_id},
            id      => $param->{id},
        },
    );
    if ( $rc->id() ) {

        try {
            $rc->delete();
        }
        catch {
            return undef;
        };

        return TRUE;
    }
    else {
        return FALSE;
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
        $rc->update(
            {

                fields  => $param->{fields},
                user_id => $param->{user_id},

            }
        );
        return TRUE;
    }
    else {
        return FALSE;
    }
}

sub list {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_page')->get(
        select => [
            qw{

                rp.id
                rp.ringpage

                },
        ],
        table => 'ring_page rp',
        where => { 'rp.user_id' => $param->{user_id}, },
    );
    return $q;
}

sub retrieve {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_page')->get(
        select => [
            qw{

                rp.fields
                rp.id
                rp.ringpage
                rp.template

                },
        ],
        table => 'ring_page rp',
        where => { 'rp.id' => $param->{ringpage_id}, },
    );

    return $q->[0];
}

1;
