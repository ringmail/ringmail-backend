package Page::ring::setup::hashtag;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use English '-no_match_vars';

use Note::XML 'xml';
use Note::Param;

use Ring::User;

use Ring::Model::Hashtag;
use Ring::Model::Category;
use Ring::Model::RingPage;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $form    = $self->form();
    my $user    = $self->user();
    my $content = $self->content();

    my $hashtag_id = $form->{id};

    if ( not $hashtag_id =~ m{ \A \d+ \z }xms ) {
        return $self->redirect('/u/hashtags');
    }

    my $category_model = Ring::Model::Category->new();
    my $categories     = $category_model->list();
    my %categories     = map { $ARG->{id} => $ARG->{category} } @{$categories};

    {

        my $hashtag = Note::Row->new(
            ring_hashtag => {
                id      => $hashtag_id,
                user_id => $user->id(),
            },
        );

        if ( not defined $hashtag->id() ) {
            return $self->redirect('/u/hashtags');
        }

        my $ringpage_row = Note::Row->new(
            ring_page => {
                id      => $hashtag->data( 'ringpage_id', ),
                user_id => $user->id(),
            },
        );

        my $ringpage = defined $ringpage_row->id() ? $ringpage_row->data( 'ringpage', ) : undef;

        $content->{category_sel} = $hashtag->data( 'category_id', );
        $content->{category}     = $categories{ $hashtag->data( 'category_id', ) };
        $content->{edit}         = ( $form->{edit} ) ? 1 : 0;
        $content->{hashtag}      = $hashtag->data( 'hashtag', );
        $content->{ringpage_sel} = $hashtag->data( 'ringpage_id', );
        $content->{ringpage}     = $ringpage;
        $content->{target_url}   = $hashtag->data( 'target_url', );

    }

    my @categories;

    if ( scalar @{$categories} ) {
        push @categories, map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories};
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

    return $self->SUPER::load( $param, );
}

sub cmd_hashtag_edit {
    my ( $self, $form_data, $args, ) = @_;

    my $user             = $self->user();
    my $target           = $form_data->{target};
    my ( $ringpage_id, ) = ( $form_data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );
    my ( $hashtag_id, )  = ( @{$args}, );

    $target =~ s{ \A \s* }{}xms;    # trim whitespace
    $target =~ s{ \s* \z }{}xms;
    if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
        $target = "http://$target";
    }

    my $hashtag_model = Ring::Model::Hashtag->new();

    if ( $hashtag_model->validate_target( target => $target, ) or defined $ringpage_id ) {
        if ($hashtag_model->update(
                category_id => $form_data->{category_id},
                id          => $hashtag_id,
                ringpage_id => $ringpage_id,
                target      => defined $ringpage_id ? undef : $target,
                user_id     => $user->id(),
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
