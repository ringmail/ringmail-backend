package Page::ring::setup::hashtags;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::Model::Hashtag;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    #my $form = $obj->form();
    #::_log($form);
    my $content = $obj->content();
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $factory = Ring::Model::Hashtag->new();
    my $ht      = $factory->get_user_hashtags( 'user_id' => $uid, );
    ::log($ht);
    $content->{'hashtag_table'} = $ht;
    return $obj->SUPER::load($param);
}

sub cmd_hashtag_add {
    my ( $obj, $data, $args ) = @_;
    my $user   = $obj->user();
    my $uid    = $user->id();
    my $tag    = lc( $data->{'hashtag'} );
    my $target = $data->{'target'};
    $target =~ s/^\s*//xms;    # trim whitespace
    $target =~ s/\s*$//xms;
    unless ( $target =~ m{^http(s)?://}xmsi ) {
        $target = 'http://' . $target;
    }
    my $factory = Ring::Model::Hashtag->new();
    if ( $factory->validate_tag( 'tag' => $tag, ) ) {
        if ( $factory->check_exists( 'tag' => $tag, ) ) {
            ::log("Dup");
        }
        else {
            if ( $factory->validate_target( 'target' => $target, ) ) {
                my $res = $factory->create(
                    'tag'        => $tag,
                    'user_id'    => $uid,
                    'target_url' => $target,
                );
                if ( defined $res ) {

                    #::log("New", $res);
                }
            }
            else {
                ::log("Bad Target");
            }
        }
    }

    return;
}

sub cmd_hashtag_delete {
    my ( $obj, $data, $args ) = @_;
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $tagid   = $args->[0];
    my $factory = Ring::Model::Hashtag->new();
    if ($factory->delete(
            'user_id' => $uid,
            'id'      => $tagid,
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

