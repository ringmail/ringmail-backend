package Page::ring::setup::ringpages;

use English '-no_match_vars';
use JSON::XS 'encode_json';
use List::MoreUtils 'each_arrayref';
use Moose;
use Note::Param;
use Ring::Model::Hashtag;
use Ring::Model::RingPage;
use Ring::Model::Template;
use strict;
use warnings;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();
    my $user    = $self->user();

    my $template = Ring::Model::Template->new( caller => $self, );
    my $templates = $template->list();

    my @templates;

    push @templates, map { [ $templates->{$ARG}->{title} => $ARG, ]; } sort keys $templates;

    $content->{template_list}       = \@templates;
    $content->{template_sel}        = 0;
    $content->{template_opts}->{id} = 'template_name';

    my $ringpage_model = Ring::Model::RingPage->new();
    my $ringpages = $ringpage_model->list( user_id => $user->id(), );
    $content->{ringpages} = $ringpages;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args ) = @_;

    my $user           = $self->user();
    my $ringpage_model = Ring::Model::RingPage->new();
    my $ringpage_name  = $form_data->{ringpage};

    if ( $ringpage_model->validate_ringpage( ringpage => $ringpage_name, ) ) {

        if ( $ringpage_model->check_exists( ringpage => $ringpage_name, ) ) {
            ::log('Dup');
        }
        else {

            my $template_name = $form_data->{template_name};

            my $template_model = Ring::Model::Template->new( caller => $self, );
            my $templates = $template_model->list();

            my $template_structure = $templates->{$template_name}->{structure};

            for my $field ( @{ $template_structure->{fields} } ) {

                my $name    = $field->{name};
                my $value   = $form_data->{$name};
                my $default = $field->{default};

                $field->{value} = $value // $default;
            }

            my $ringpage = $ringpage_model->create(
                fields        => encode_json $template_structure->{fields},
                ringpage      => $ringpage_name,
                template_name => $template_name,
                user_id       => $user->id(),
            );
            if ( defined $ringpage ) {

                my $each_array = each_arrayref [ 'Call', ], [ 'ring://' . $user->row()->data( 'login', ), ];
                while ( my ( $button_text, $button_link, ) = $each_array->() ) {

                    next if $button_text eq q{} or $button_link eq q{};

                    my $row = Note::Row::create(
                        ring_button => {
                            button      => $button_text,
                            ringpage_id => $ringpage->id(),
                            uri         => $button_link,
                            user_id     => $user->id(),
                        },
                    );
                }

                my ( $hashtag_id, ) = ( $form_data->{hashtag_id} =~ m{ \A ( \d+ ) \z }xms, );

                if ( defined $hashtag_id ) {

                    my $hashtag_row = Note::Row->new(
                        ring_hashtag => {
                            id      => $hashtag_id,
                            user_id => $user->id(),
                        },
                    );

                    my $hashtag_row_data = $hashtag_row->data();

                    if ( defined $hashtag_row ) {

                        my $hashtag_model = 'Ring::Model::Hashtag'->new();

                        if ($hashtag_model->update(
                                category_id => $hashtag_row_data->{category_id},
                                id          => $hashtag_id,
                                ringpage_id => $ringpage->id(),
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
                }

                return $self->redirect( $self->url( path => '/u/ringpage', query => { ringpage_id => $ringpage->id(), }, ), );

            }
        }
    }

    return;
}

sub remove {
    my ( $self, $form_data, $args, ) = @_;

    my $user = $self->user();
    my ( $ringpage_id, ) = @{$args};

    if ( $ringpage_id =~ m{ \A ( \d+ ) \z }xms ) {

        my $ringpage_model = Ring::Model::RingPage->new();

        if ($ringpage_model->delete(
                id      => $ringpage_id,
                user_id => $user->id(),
            )
            )
        {
            # display confirmation
        }
        else {
            # failed
        }

    }

    return;
}

1;
