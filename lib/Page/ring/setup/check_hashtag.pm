package Page::ring::setup::check_hashtag;

use strict;
use warnings;

use Moose;

use Note::Param;

use Ring::User;
use Page::ring::user;

use parent 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    return $self->$next( $param, );
};

sub check_hashtag {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    ::log( $self, $param, );

    $self->form()->{hashtag} = $param->{hashtag};

    $self->value()->{available} = 1 if $param->{hashtag} eq 'foobar';

    return;
}

1;
