package Page::ring::setup::index;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::API;
use Page::ring::user;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $form     = $self->form();
    my $content  = $self->content();
    my $user     = $self->user();
    my $user_row = $user->row();
    my $login    = $user_row->data( 'login', );

    ::_log( $form, );

    $content->{email} = $login;

    return $self->SUPER::load( $param, );
}

1;

