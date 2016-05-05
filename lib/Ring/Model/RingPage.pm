package Ring::Model::RingPage;

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

                ringpage                => $param->{ringpage},
                header_background_color => $param->{header_background_color},
                header_text_color       => $param->{header_text_color},
                body_background_image   => $param->{body_background_image},
                body_background_color   => $param->{body_background_color},
                body_text_color         => $param->{body_text_color},
                footer_background_color => $param->{footer_background_color},
                footer_text_color       => $param->{footer_text_color},
                template_id             => $param->{template_id},
                user_id                 => $param->{user_id},

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
        $rc->update(
            {

                ringpage                => $param->{ringpage},
                header_background_color => $param->{header_background_color},
                header_text_color       => $param->{header_text_color},
                body_background_image   => $param->{body_background_image},
                body_background_color   => $param->{body_background_color},
                body_text_color         => $param->{body_text_color},
                footer_background_color => $param->{footer_background_color},
                footer_text_color       => $param->{footer_text_color},

            }
        );
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
        select => [ 'rp.id',        'rp.ringpage', 't.path', ],
        table  => [ 'ring_page rp', 'ring_template t', ],
        join   => [ 'rp.template_id = t.id', ],
        where => { 'rp.user_id' => $param->{user_id}, },
    );
    return $q;
}

sub retrieve {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $q = sqltable('ring_page')->get(
        select => [

            'rp.id',
            'rp.header_background_color',
            'rp.header_text_color',
            'rp.body_background_image',
            'rp.body_background_color',
            'rp.body_text_color',
            'rp.footer_background_color',
            'rp.footer_text_color',

        ],
        table => [ 'ring_page rp', 'ring_template t', ],
        join  => [ 'rp.template_id = t.id', ],
        where => { 'rp.user_id' => $param->{user_id}, 'rp.id' => $param->{id}, },
    );

    return $q->[0];
}

1;
