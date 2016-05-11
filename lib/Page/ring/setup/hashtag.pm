package Page::ring::setup::hashtag;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use English '-no_match_vars';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::Model::Hashtag;
use Ring::Model::Category;
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
    if ( not $id =~ m{ \A \d+ \z }xms ) {
        return $obj->redirect('/u/hashtags');
    }
    my $hashtag = Note::Row->new(
        ring_hashtag => {
            id      => $id,
            user_id => $uid,
        },
    );

    if ( not defined $hashtag->id() ) {
        return $obj->redirect('/u/hashtags');
    }
    $content->{category}   = $hashtag->data('category');
    $content->{hashtag}    = $hashtag->data('hashtag');
    $content->{target_url} = $hashtag->data('target_url');
    $content->{edit}       = ( $form->{edit} ) ? 1 : 0;

    my $category   = Ring::Model::Category->new();
    my $categories = $category->get_categories();

    my @categories;

    if ( scalar @{$categories} ) {
        push @categories, map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories};
    }
    else {
        push @categories, [ '(No Categories Created)' => 0, ];
    }

    $content->{category_list}       = \@categories;
    $content->{category_sel}        = 0;
    $content->{category_opts}->{id} = 'category';

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );

    my @ringpages;

    if ( scalar @{$ringpages} ) {
        push @ringpages, map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages};
    }
    else {
        push @ringpages, [ '(No Ringpages Created)' => 0, ];
    }

    $content->{ringpage_list}       = \@ringpages;
    $content->{ringpage_sel}        = 0;
    $content->{ringpage_opts}->{id} = 'ringpage';

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

