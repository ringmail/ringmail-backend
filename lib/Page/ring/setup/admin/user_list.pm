package Page::ring::setup::admin::user_list;

use constant::boolean;
use Email::Valid;
use English '-no_match_vars';
use HTML::Escape 'escape_html';
use List::MoreUtils 'singleton';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Quantum::Superpositions qw{ any all eigenstates };
use Regexp::Common 'whitespace';

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $user    = $self->user();
    my $content = $self->content();

    my $users = sqltable('ring_user')->get(
        select    => [ qw{ u.id u.login ua.user_id }, ],
        table     => [ 'ring_user AS u', ],
        join_left => [ [ 'ring_user_admin AS ua' => 'u.id = ua.user_id', ], ],
    );

    $content->{users} = $users;

    return $self->SUPER::load( $param, );
}

sub make_admin {
    my ( $self, $form_data, $args, ) = @_;

    my $request = $self->request();
    my $user    = $self->user();
    my $user_id = $user->id();

    my $users = sqltable('ring_user')->get(
        select    => [ qw{ u.id u.login ua.user_id }, ],
        table     => [ 'ring_user AS u', ],
        join_left => [ [ 'ring_user_admin AS ua' => 'u.id = ua.user_id', ], ],
    );

    my @users         = map { $ARG->{id} + 0 } @{$users};
    my @users_admin   = map { $ARG->{id} + 0 } grep { defined $ARG->{user_id} and $ARG->{id} == $ARG->{user_id} } @{$users};
    my @users_checked = map { $ARG + 0 } $request->parameters()->get_all( 'd4-user_id', );

    my @users_admin_delete = singleton @users, @users_checked;

    my @users_admin_add = eigenstates( any( @users_checked, ) != all( @users_admin, ) );

    for my $user_id (@users_admin_delete) {

        my $user_admin_row = 'Note::Row'->new( ring_user_admin => { user_id => $user_id, }, );

        if ( defined $user_admin_row->id() ) {

            $user_admin_row->delete();
        }

    }

    for my $user_id (@users_admin_add) {

        my $user_admin_row = 'Note::Row::create'->( ring_user_admin => { user_id => $user_id, }, );

    }

    return $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );
}

sub login {
    my ( $self, $form_data, $args, ) = @_;

    my ( $user_id, ) = ( @{$args}, );

    my $session = $self->session();

    $session->{login_ringmail}          = $user_id;
    $session->{login_ringmail_original} = $self->user()->id();

    $self->session_write();

    my $user = 'Ring::User'->new( $session->{login_ringmail}, );

    $self->user( $user, );

    $self->redirect( $self->url( path => '/u', ), );

    return;
}

sub add_user {
    my ( $self, $form_data, $args, ) = @_;

    my ( $email, ) = ( $form_data->{email}, );

    if (Email::Valid->address(
            -address  => $email,
            -mxcheck  => TRUE,
            -tldcheck => TRUE,
        )
        )
    {

        ::log( $email, );

    }
    else {

        $self->form()->{email}  = $form_data->{email};
        $self->value()->{error} = "Email '$form_data->{email}' is invalid.";

    }

    return $self->redirect( $self->url( path => join q{/}, @{ $self->path() }, ), );
}

1;
