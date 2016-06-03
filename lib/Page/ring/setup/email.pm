package Page::ring::setup::email;

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

    my ( $obj, $param ) = get_param( @args, );
    my $form = $obj->form();

    #::_log($form);
    my $content = $obj->content();
    my $val     = $obj->value();
    my $user    = $obj->user();
    my $uid     = $user->id();
    $content->{'email'} = $user->row()->data('login');
    return $obj->SUPER::load($param);
}

1;
