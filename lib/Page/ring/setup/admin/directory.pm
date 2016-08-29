package Page::ring::setup::admin::directory;

use Moose;
use Note::Param;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();
    my $form    = $self->form();

    return $self->SUPER::load( $param, );
}

1;
