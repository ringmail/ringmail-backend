package Page::ring::setup::ringpage;

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
use Ring::Model::RingPage;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my $content = $obj->content();
    my $form    = $obj->form();
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $id      = $form->{'id'};
    unless ( $id =~ qr{ \A \d+ \z }xms ) {
        return $obj->redirect('/u/ringpages');
    }
    my $ht = Note::Row->new(
        ring_page => {
            id      => $id,
            user_id => $uid,
        },
    );

    unless ( $ht->id() ) {
        return $obj->redirect('/u/ringpages');
    }
    $content->{ringpage}     = $ht->data('ringpage');
    $content->{ringlink}     = $ht->data('ringlink');
    $content->{ringlink_url} = $ht->data('ringlink_url');
    $content->{edit}         = ( $form->{'edit'} ) ? 1 : 0;

    return $obj->$next( $param, );
};

sub edit {
    my ( $obj, $data, $args ) = @_;
    my $user         = $obj->user();
    my $uid          = $user->id();
    my $id           = $args->[0];
    my $ringlink_url = $data->{ringlink_url};
    $ringlink_url =~ s{ \A \s* }{}xms;    # trim whitespace
    $ringlink_url =~ s{ \s* \z }{}xms;
    unless ( $ringlink_url =~ m{ \A http(s)?:// }xmsi ) {
        $ringlink_url = 'http://' . $ringlink_url;
    }
    my $factory = Ring::Model::RingPage->new();
    if ( $factory->validate_ringpage( ringlink_url => $ringlink_url, ) ) {
        if ($factory->update(
                user_id      => $uid,
                id           => $id,
                ringlink_url => $ringlink_url,
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
        # invalid ringlink_url
    }

    return;
}

1;
