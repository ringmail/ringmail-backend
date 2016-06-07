package Page::ring::setup::check_hashtag;

use strict;
use warnings;

use Moose;

use Note::Param;
use Ring::Model::Hashtag;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    return $self->$next( $param, );
};

sub check_hashtag {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    $self->form()->{hashtag} = $param->{hashtag};

    my $hashtag_model = Ring::Model::Hashtag->new();

    $self->value()->{hashtag} = $hashtag_model->check_exists( tag => $param->{hashtag}, );

    return;
}

1;
