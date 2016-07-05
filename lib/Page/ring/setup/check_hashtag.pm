package Page::ring::setup::check_hashtag;

use strict;
use warnings;

use Moose;

use Note::Param;
use Ring::Model::Hashtag;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    return $self->SUPER::load( $param, );
}

sub check_hashtag {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    return if not length $param->{hashtag} > 0;

    $self->form()->{hashtag} = $param->{hashtag};

    my $hashtag_model = Ring::Model::Hashtag->new();

    $self->value()->{hashtag} = $hashtag_model->check_exists( tag => $param->{hashtag}, );

    return;
}

1;
