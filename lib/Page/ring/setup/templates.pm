package Page::ring::setup::templates;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;
use Note::Account qw(account_id transaction tx_type_id);

use Ring::User;
use Ring::Model::Template;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    #my $form = $obj->form();
    #::_log($form);
    my $content   = $obj->content();
    my $user      = $obj->user();
    my $uid       = $user->id();
    my $factory   = Ring::Model::Template->new();
    my $templates = $factory->get_user_templates( 'user_id' => $uid, );
    $content->{'templates'} = $templates;
    return $obj->$next( $param, );
};

sub add_template {
    my ( $obj, $data, $args ) = @_;
    my $user     = $obj->user();
    my $uid      = $user->id();
    my $template = $data->{template};
    my $path     = $data->{path};
    my $factory  = Ring::Model::Template->new();

    if ( $factory->validate_template( template => $template, ), ) {

        if ( $factory->check_exists( template => $template, ), ) {
            ::log('Dup');
        }
        else {

            ::log( 'got create in controller', );

            my $res = $factory->create(
                template => $template,
                path     => $path,
                user_id  => $uid,
            );
            if ( defined $res ) {
                ::log( New => $res );
            }
        }
    }

    return;
}

sub delete_template {
    my ( $obj, $data, $args ) = @_;
    my $user        = $obj->user();
    my $uid         = $user->id();
    my $template_id = $args->[0];
    my $factory     = Ring::Model::Template->new();
    if ($factory->delete(
            'id'      => $template_id,
            'user_id' => $uid,
        )
        )
    {
        # display confirmation
    }
    else {
        # failed
    }

    return;
}

1;
