package Ring::Model::Hashtag;

use Carp 'croak';
use constant::boolean;
use English '-no_match_vars';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'URI';
use Try::Tiny;

our $VERSION = 1;

sub validate_tag {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $tag = lc $param->{tag};

    if ( $tag =~ m{ \A \w+ \z }xms ) {

        return TRUE;
    }
    else {

        return FALSE;
    }

    return;
}

sub validate_target {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $target = $param->{target};

    if ( $target =~ m{ \A $RE{URI}{HTTP}{ -scheme => qr{ https? }xms, } \z }xms ) {

        return TRUE;
    }
    else {

        return FALSE;
    }

    return;
}

sub check_exists {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $tag = lc $param->{tag};

    if ( not $self->validate_tag( tag => $tag, ) ) {

        croak( "Invalid hashtag: #$tag", );
    }

    return sqltable('ring_hashtag')->count( hashtag => $tag, );
}

sub create {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $tag = lc $param->{tag};

    if ( not $self->validate_tag( tag => $tag, ) ) {
        croak( "Invalid hashtag: #$tag", );
    }

    my $hashtag_row;

    try {

        $hashtag_row = 'Note::Row::insert'->(
            ring_hashtag => {
                hashtag     => $tag,
                ts_expires  => $param->{expires},
                user_id     => $param->{user_id},
            }
        );

    }
    catch {

        my $err = $ARG;

        if ( $err =~ m{ Duplicate }xms ) {

            return undef;    ## no critic ( Perl::Critic::Policy::Subroutines::ProhibitExplicitReturnUndef )
        }
        else {

            croak( $err, );
        }

    };

    return $hashtag_row;
}

sub delete {                 ## no critic ( Perl::Critic::Policy::Subroutines::ProhibitBuiltinHomonyms )
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $hashtag_row = 'Note::Row'->new(
        ring_hashtag => {
            id      => $param->{id},
            user_id => $param->{user_id},
        },
    );

    if ( defined $hashtag_row->id() ) {

        $hashtag_row->delete();

        return TRUE;
    }
    else {

        return FALSE;
    }

    return;
}

sub update {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $hashtag_row = 'Note::Row'->new(
        ring_hashtag => {
            user_id => $param->{user_id},
            id      => $param->{id},
        },
    );

    if ( $hashtag_row->id() ) {

        $hashtag_row->update(
            {

                category_id => $param->{category_id},
                ringpage_id => $param->{ringpage_id},
                target_url  => $param->{target},

            },
        );

        return TRUE;
    }
    else {

        return FALSE;
    }

    return;
}

sub get_user_hashtags {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $hashtags = sqltable('ring_hashtag')->get(
        select => [ 'id', 'hashtag', 'ts_expires as expires', 'target_url' ],
        where => { user_id => $param->{user_id}, },
        order => 'hashtag asc',
    );

    return $hashtags;
}

1;
