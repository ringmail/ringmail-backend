package Ring::User::Admin;

use constant::boolean;
use Moose::Role;
use Note::Row;

has is_admin => ( is => 'rw', isa => 'Bool', );

sub role_admin {
    my ( $self, ) = @_;

    $self->check_admin();

    if ( $self->is_admin() ) {

        return TRUE;
    }
    else {

        $self->redirect( $self->url( path => '/login', ), );
    }

    return;
}

sub check_admin {
    my ( $self, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my $ring_user_admin_row = Note::Row->new( ring_user_admin => { user_id => $user_id, }, );

    if ( defined $ring_user_admin_row->id() ) {

        $self->is_admin( TRUE, );
    }
    else {

        $self->is_admin( FALSE, );
    }

    return $self->is_admin();
}

1;
