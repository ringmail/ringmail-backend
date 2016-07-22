package Page::ring::setup::admin::user_list;

use Moose;
use Note::Param;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    return $self->SUPER::load( $param, );
}

1;
