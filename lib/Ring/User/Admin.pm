package Ring::User::Admin;

use Moose::Role;
use constant::boolean;
use Note::Row;

has is_admin => ( is => 'rw', isa => 'Bool', default => FALSE, );

sub role_admin {
    my ( $self, ) = @_;

    ::log( $self, );

    my $user    = $self->user();
    my $user_id = $user->id();

    my $ring_user_admin_row = Note::Row->new( ring_user_admin => { user_id => $user_id, }, );

    ::log( $ring_user_admin_row, );

    $self->is_admin( defined $ring_user_admin_row->id() ? TRUE : FALSE, );

    return TRUE;
}

1;
