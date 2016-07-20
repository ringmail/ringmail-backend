package Page::ring::setup::ringpage;

use constant::boolean;
use English '-no_match_vars';
use HTML::Escape 'escape_html';
use JSON::XS qw{ encode_json decode_json };
use List::MoreUtils qw{ each_arrayref first_value };
use Moose;
use Note::Param;
use Note::SQL::Table 'sqltable';
use Note::XML 'xml';
use Ring::Model::RingPage;
use Ring::Model::Template;
use Ring::User;
use strict;
use warnings;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content     = $self->content();
    my $form        = $self->form();
    my $user        = $self->user();
    my $user_id     = $user->id();
    my $ringpage_id = $form->{ringpage_id};
    if ( not $ringpage_id =~ m{ \A \d+ \z }xms ) {
        return $self->redirect('/u/ringpages');
    }
    my $ringpage_row = Note::Row->new(
        ring_page => {
            id      => $ringpage_id,
            user_id => $user_id,
        },
    );

    if ( not $ringpage_row->id() ) {
        return $self->redirect('/u/ringpages');
    }

    my $ringpage_row_data = $ringpage_row->data();
    my $ringpage_fields   = decode_json $ringpage_row_data->{fields};

    for my $field ( @{$ringpage_fields} ) {

        my $name    = $field->{name};
        my $value   = $field->{value};
        my $default = $field->{default};

        $ringpage_row_data->{$name} = $value // $default;
    }

    my $template_model    = Ring::Model::Template->new( caller => $self, );
    my $templates         = $template_model->list();
    my $template_name     = $ringpage_row_data->{template};
    my $ringpage_template = $templates->{$template_name};

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ qw{ id button uri }, ],
        where  => { ringpage_id => $ringpage_row->id(), },
        order  => 'id',
    );

    $content->{ringpage_template} = $ringpage_template;
    $content->{ringpage}          = $ringpage_row_data;
    $content->{buttons}           = $buttons;
    $content->{edit}              = $form->{edit} ? 1 : 0;

    return $self->SUPER::load( $param, );
}

sub edit {
    my ( $self, $form_data, $args, ) = @_;

    my ( $ringpage_id, ) = @{$args};
    my $user             = $self->user();
    my $user_id          = $user->id();

    my $ringpage_row = Note::Row->new(
        ring_page => {
            id      => $ringpage_id,
            user_id => $user_id,
        },
    );

    my $ringpage_row_data  = $ringpage_row->data();
    my $template_model     = Ring::Model::Template->new( caller => $self, );
    my $templates          = $template_model->list();
    my $template_name      = $ringpage_row_data->{template};
    my $template_structure = $templates->{$template_name}->{structure};

    my $theme_name = $form_data->{theme_name};

    for my $theme ( @{ $template_structure->{themes} } ) {

        if ( $theme->{name} eq $theme_name ) {

            for my $name ( keys %{$theme} ) {

                $form_data->{$name} = $theme->{$name};

            }

        }

    }

    my $ringpage_fields = decode_json $ringpage_row->data( 'fields', );
    my %ringpage_fields = map { $ARG->{name} => $ARG->{value} } @{$ringpage_fields};

    for my $field ( @{ $template_structure->{fields} } ) {

        my $name       = $field->{name};
        my $form_value = escape_html $form_data->{$name};

        if ( defined $field->{internal} and $field->{internal} == TRUE ) {

            $field->{value} = $ringpage_fields{$name};

        }
        elsif ( defined $form_value ) {

            if ( $field->{text_type} eq 'url' ) {

                if ( not $form_value =~ m{ \A http(s)?:// }xmsi and length $form_value > 0 ) {

                    $form_value = 'http://' . $form_value;

                }

            }

            $field->{value} = $form_value;

        }
        else {

            $field->{value} = $ringpage_fields{$name};

        }

    }

    my $ringpage_model = Ring::Model::RingPage->new();

    if ($ringpage_model->update(
            fields  => encode_json $template_structure->{fields},
            id      => $ringpage_id,
            user_id => $user_id,
        )
        )
    {
        # display confirmation

        my $each_array = each_arrayref [ first_value { length > 0; } $self->request()->parameters()->get_all( 'd2-button_id', ), ], [ first_value { length > 0; } $self->request()->parameters()->get_all( 'd2-button_text', ), ], [ first_value { length > 0; } $self->request()->parameters()->get_all( 'd2-button_link', ), ];
        while ( my ( $button_id, $button_text, $button_link, ) = $each_array->() ) {

            if ( $button_id eq q{} ) {

                next if $button_text eq q{} or $button_link eq q{};

                my $button_row = Note::Row::create(
                    ring_button => {
                        button      => $button_text,
                        ringpage_id => $ringpage_id,
                        uri         => $button_link,
                        user_id     => $user->id(),
                    },
                );

            }

            else {

                my $button_row = Note::Row->new( ring_button => $button_id, );

                if ( $button_text eq q{} or $button_link eq q{} ) {

                    $button_row->delete();

                }

                else {

                    $button_row->update( { button => $button_text, uri => $button_link, }, );

                }

            }

        }

    }
    else {
        # failed
    }

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => { ringpage_id => $ringpage_id, }, ), );
}

sub button_delete {
    my ( $self, $form_data, $args, ) = @_;

    my $user    = $self->user();
    my $user_id = $user->id();

    my ( $ringpage_id, $button_id, ) = @{$args};

    my $button_row = Note::Row->new( ring_button => { id => $button_id, user_id => $user_id, }, );

    if ( $button_row->delete() ) {

        # display confirmation
    }
    else {
        # failed
    }

    $self->form()->{ringpage_id} = $ringpage_id;

    return;
}

1;
