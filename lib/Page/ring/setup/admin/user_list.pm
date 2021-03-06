package Page::ring::setup::admin::user_list;

use constant::boolean;
use Email::Valid;
use English '-no_match_vars';
use HTML::Escape 'escape_html';
use Math::Random::Secure 'rand';
use Moose;
use Note::Param;
use Note::Row;
use Note::SQL::Table 'sqltable';
use Readonly;
use Ref::Util 'is_arrayref';
use Regexp::Common 'whitespace';
use Ring::API;
use String::Random 'random_regex';

extends 'Page::ring::user';

Readonly my $PAGE_SIZE => 10;

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my ( $search, ) = ( $self->form()->{search}, );

    my $where_clause = {

        defined $search ? ( 'ring_user.login' => [ like => qq{%$search%}, ], ) : (),

    };

    $self->content()->{count} = sqltable('ring_user')->count( $where_clause, );

    my ( $page, ) = ( $self->form()->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $page_size = $self->app()->config()->{page_size} // $PAGE_SIZE;

    $self->content()->{users} = sqltable('ring_user')->get(
        select    => [ qw{ ring_user.id ring_user.login ring_user_admin.user_id }, ],
        table     => [ 'ring_user', ],
        join_left => [ [ ring_user_admin => 'ring_user.id = ring_user_admin.user_id', ], ],
        where     => $where_clause,
        order     => qq{ring_user.login LIMIT ${ \ do { ( $page - 1 ) * $page_size } }, $page_size},
    );

    return $self->SUPER::load( $param, );
}

sub admin {
    my ( $self, $form_data, $args, ) = @_;

    my @users_admin   = map { $ARG + 0 } $self->request()->parameters()->get_all( "d${ \$self->cmdnum() }-user_id-admin", );
    my @users_checked = map { $ARG + 0 } $self->request()->parameters()->get_all( "d${ \$self->cmdnum() }-user_id", );

    my %users_admin;
    @users_admin{@users_admin} = undef;

    my %users_checked;
    @users_checked{@users_checked} = undef;

    for my $user_id (@users_checked) {
        delete $users_admin{$user_id};
    }

    for my $user_id (@users_admin) {
        delete $users_checked{$user_id};
    }

    my @users_admin_delete = keys %users_admin;
    my @users_admin_add    = keys %users_checked;

    for my $user_id (@users_admin_delete) {

        my $user_admin_row = 'Note::Row'->new( ring_user_admin => { user_id => $user_id, }, );

        if ( defined $user_admin_row->id() ) {

            $user_admin_row->delete();
        }

    }

    for my $user_id (@users_admin_add) {

        my $user_admin_row = 'Note::Row::insert'->( ring_user_admin => { user_id => $user_id, }, );

    }

    my ( $page, )   = ( ( $self->form()->{page}   // 1 ) =~ m{ \A ( \d+ ) \z }xms, );
    my ( $search, ) = ( ( $self->form()->{search} // q{} ) =~ m{ \A ( \w+ ) \z }xms, );

    my $query = {

        defined $page   ? ( page   => $page, )   : (),
        defined $search ? ( search => $search, ) : (),

    };

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => $query, ), );

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

sub add {
    my ( $self, $form_data, $args, ) = @_;

    my $form  = $self->form();
    my $value = $self->value();

    my ( $email, ) = ( $form_data->{email}, );

    my $email_valid = Email::Valid->address(
        -address  => $email,
        -mxcheck  => TRUE,
        -tldcheck => TRUE,
    );

    if ( defined $email_valid ) {

        my $password = random_regex '[A-Za-z0-9]{12}';

        my $response = Ring::API->cmd(
            path => [ qw{ user create }, ],
            data => {
                email     => $email_valid,
                password  => $password,
                password2 => $password,
            },
        );

        if ( exists $response->{errors} ) {

            my ( $error, ) = ( @{ $response->{errors} }, );

            if ( is_arrayref $error ) {

                my ( $type, $message, ) = ( @{$error}, );

                $form->{email}  = $email_valid;
                $value->{error} = $message;

                return;

            }

        }

    }
    else {

        $form->{email}  = $email;
        $value->{error} = "Email '$form_data->{email}' is invalid.";

        return;

    }

    return;
}

sub search {
    my ( $self, $form_data, $args, ) = @_;

    my $form = $self->form();

    my ( $search, ) = ( $form_data->{search} =~ m{ /A /z }xms, );

    $self->form()->{search} = $form_data->{search};

    if ( defined $search ) {

        $self->value()->{search} = $search;
    }

    return;
}

1;
