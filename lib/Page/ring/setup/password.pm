package Page::ring::setup::password;

use Moose;
use Note::Param;
use Ring::User;
use strict;
use warnings;
use Readonly;

Readonly my $PASSWORD_LENGTH => 4;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my $form = $obj->form();

    my $content = $obj->content();
    my $user    = $obj->user();
    return $obj->SUPER::load($param);
}

sub password_change {
    my ( $obj, $data, $args ) = @_;
    my $orig = $data->{'pass_orig'};
    my $uid  = $obj->user()->id();
    my $rc   = 'Note::Row'->new(
        'ring_user' => { 'id' => $uid, },
        { 'select' => [qw/password_salt password_hash/], },
    );
    my $ok = 0;
    if ( $rc->id() ) {
        my $user = 'Ring::User'->new( $rc->id() );
        if ($user->check_password(
                'salt'     => $rc->data('password_salt'),
                'hash'     => $rc->data('password_hash'),
                'password' => $orig,
            )
            )
        {
            my $np = $data->{'pass_1'};
            if ( not( length($np) >= $PASSWORD_LENGTH ) ) {
                $obj->value()->{'error'} = "Password must be at least $PASSWORD_LENGTH characters";
                return;
            }
            if ( not( $np eq $data->{'pass_2'} ) ) {
                $obj->value()->{'error'} = 'Passwords do not match';
                return;
            }
            $user->password_change( 'password' => $np, );

            # TODO: Clear freeswitch registration cache
            $obj->value()->{'message'} = 'Password changed';
        }
        else {
            $obj->value()->{'error'} = 'Incorrect current password';
            return;
        }
    }

    return;
}

1;
