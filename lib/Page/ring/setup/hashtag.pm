package Page::ring::setup::hashtag;

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
use Ring::Model::Hashtag;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );
    my $content = $obj->content();
    my $form    = $obj->form();
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $id      = $form->{'id'};
    if ( not $id =~ m{ \A \d+ \z }xms ) {
        return $obj->redirect('/u/hashtags');
    }
    my $ht = Note::Row->new(
        'ring_hashtag' => {
            'id'      => $id,
            'user_id' => $uid,
        },
    );

    #::log($ht->data());
    if ( not defined $ht->id() ) {
        return $obj->redirect('/u/hashtags');
    }
    $content->{'hashtag'}    = $ht->data('hashtag');
    $content->{'target_url'} = $ht->data('target_url');
    $content->{'edit'}       = ( $form->{'edit'} ) ? 1 : 0;
    return $obj->$next( $param, );
};

sub cmd_hashtag_edit {
    my ( $obj, $data, $args ) = @_;
    my $user   = $obj->user();
    my $uid    = $user->id();
    my $tagid  = $args->[0];
    my $target = $data->{'target'};
    $target =~ s{ \A \s* }{}xms;    # trim whitespace
    $target =~ s{ \s* \z }{}xms;
    if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
        $target = 'http://' . $target;
    }
    my $factory = Ring::Model::Hashtag->new();
    if ( $factory->validate_target( 'target' => $target, ) ) {
        if ($factory->update(
                'user_id' => $uid,
                'id'      => $tagid,
                'target'  => $target,
            )
            )
        {
            # display confirmation
        }
        else {
            # failed
        }
    }
    else {
        # invalid target
    }

    return;
}

1;

