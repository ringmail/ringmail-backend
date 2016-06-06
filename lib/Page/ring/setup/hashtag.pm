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
    my ( $self, $param ) = get_param( @args, );
    my $content = $self->content();
    my $form    = $self->form();
    my $user    = $self->user();
    my $uid     = $user->id();
    my $id      = $form->{'id'};
    if ( not $id =~ m{ \A \d+ \z }xms ) {
        return $self->redirect('/u/hashtags');
    }

    {

        my $hashtag = Note::Row->new(
            ring_hashtag => {
                id      => $id,
                user_id => $uid,
            },
        );

        if ( not defined $hashtag->id() ) {
            return $self->redirect('/u/hashtags');
        }

        my $ringpage_row = Note::Row->new(
            ring_page => {
                id      => $hashtag->data( 'ringpage_id', ),
                user_id => $uid,
            },
        );

        my $ringpage = defined $ringpage_row->id() ? $ringpage_row->data( 'ringpage', ) : undef;

        $content->{category_sel} = $hashtag->data( 'category', );
        $content->{category}     = $hashtag->data( 'category', );
        $content->{edit}         = ( $form->{edit} ) ? 1 : 0;
        $content->{hashtag}      = $hashtag->data( 'hashtag', );
        $content->{ringpage_sel} = $hashtag->data( 'ringpage_id', );
        $content->{ringpage}     = $ringpage;
        $content->{target_url}   = $hashtag->data( 'target_url', );

    }

    my $category = Ring::Model::Category->new( caller => $self, );
    my $categories = $category->list();

    my @categories;

    if ( scalar @{$categories} ) {
        push @categories, map { [ $ARG->{title} => $ARG->{name}, ]; } @{$categories};
    }
    else {
        push @categories, [ '(No Categories Created)' => 0, ];
    }

    $content->{category_list} = \@categories;
    $content->{category_opts}->{id} = 'category';

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );

    my @ringpages;

    if ( scalar @{$ringpages} ) {
        push @ringpages, map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages};
    }
    else {
        push @ringpages, [ '(No RingPages Created)' => undef, ];
    }

    $content->{ringpage_list} = \@ringpages;
    $content->{ringpage_opts}->{id} = 'ringpage';

    return $self->$next( $param, );
};

sub cmd_hashtag_edit {
    my ( $self, $data, $args ) = @_;
    my $user   = $self->user();
    my $uid    = $user->id();
    my $tagid  = $args->[0];
    my $target = $data->{target};
    $target =~ s{ \A \s* }{}xms;    # trim whitespace
    $target =~ s{ \s* \z }{}xms;
    if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
        $target = 'http://' . $target;
    }

    my ( $ringpage_id, ) = ( $data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );

    my $hashtag = Ring::Model::Hashtag->new();
    if ( $hashtag->validate_target( 'target' => $target, ) ) {
        if ($hashtag->update(
                id          => $tagid,
                ringpage_id => $ringpage_id,
                target      => $target,
                user_id     => $uid,
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
