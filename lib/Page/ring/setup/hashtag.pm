package Page::ring::setup::hashtag;

use English '-no_match_vars';
use JSON::XS 'encode_json';
use Moose;
use Note::Param;
use Note::XML 'xml';
use Ring::Model::Category;
use Ring::Model::Hashtag;
use Ring::Model::RingPage;
use Ring::User;
use strict;
use warnings;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $form    = $self->form();
    my $user    = $self->user();
    my $content = $self->content();

    my $hashtag_id = $form->{hashtag_id};

    if ( not $hashtag_id =~ m{ \A \d+ \z }xms ) {
        return $self->redirect('/u/hashtags');
    }

    my $hashtag = Note::Row->new(
        ring_hashtag => {
            id      => $hashtag_id,
            user_id => $user->id(),
        },
    );

    if ( not defined $hashtag->id() ) {
        return $self->redirect('/u/hashtags');
    }

    my $category_model = Ring::Model::Category->new();
    my $categories     = $category_model->list();
    my %categories     = map { $ARG->{id} => $ARG->{category} } @{$categories};
    my $ringpage_model = Ring::Model::RingPage->new();
    my $ringpages      = $ringpage_model->list( user_id => $user->id(), );

    my $ringpage_row = Note::Row->new(
        ring_page => {
            id      => $hashtag->data( 'ringpage_id', ),
            user_id => $user->id(),
        },
    );

    my $ringpage = defined $ringpage_row->id() ? $ringpage_row->data( 'ringpage', ) : undef;

    $content->{category_list} = [ map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories}, ];
    $content->{category_sel}  = $hashtag->data( 'category_id', );
    $content->{category}      = $categories{ $hashtag->data( 'category_id', ) };
    $content->{edit}          = ( $form->{edit} ) ? 1 : 0;
    $content->{hashtag}       = $hashtag->data( 'hashtag', );
    $content->{ringpage_list} = [ map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages}, ];
    $content->{ringpage_sel}  = $hashtag->data( 'ringpage_id', );
    $content->{ringpage}      = $ringpage;
    $content->{target_url}    = $hashtag->data( 'target_url', );

    return $self->SUPER::load( $param, );
}

sub cmd_hashtag_edit {
    my ( $self, $form_data, $args, ) = @_;

    my $user             = $self->user();
    my $form             = $self->form();
    my ( $hashtag_id, )  = ( $self->form->{hashtag_id} =~ m{ \A ( \d+ ) \z }xms );
    my ( $category_id, ) = ( $form_data->{category_id} =~ m{ \A ( \d+ ) \z }xms );
    my ( $destination, ) = ( $form_data->{destination} =~ m{ \A ( \w+ ) \z }xms, );
    my ( $target, )      = ( $form_data->{target}, );
    my ( $ringpage_id, ) = ( $form_data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );

    if ( defined $destination ) {

        my $hashtag_model = Ring::Model::Hashtag->new();

        if ( $destination eq 'target_url' ) {

            $target =~ s{ \A \s* }{}xms;    # trim whitespace
            $target =~ s{ \s* \z }{}xms;
            if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
                $target = "http://$target";
            }

            if ( $hashtag_model->validate_target( target => $target, ) ) {
                if ($hashtag_model->update(
                        category_id => $category_id,
                        id          => $hashtag_id,
                        target      => $target,
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

        }

        if ( $destination eq 'ringpage' ) {

            if ( defined $ringpage_id ) {
                if ($hashtag_model->update(
                        category_id => $category_id,
                        id          => $hashtag_id,
                        ringpage_id => $ringpage_id,
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

        }

        if ( $destination eq 'ringpage_new' ) {

            if ( defined $ringpage_id ) {
                if ($hashtag_model->update(
                        category_id => $category_id,
                        id          => $hashtag_id,
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

            return $self->redirect( $self->url( path => '/u/ringpages', query => { hashtag_id => $hashtag_id, }, ), );
        }

    }

    return;
}

1;
