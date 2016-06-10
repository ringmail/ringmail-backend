package Page::ring::setup::edit_ringpage;

use strict;
use warnings;

use Moose;
use JSON::XS qw{ encode_json decode_json };
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use List::MoreUtils 'each_arrayref';

use Note::XML 'xml';
use Note::Param;
use Note::SQL::Table 'sqltable';

use Ring::User;
use Ring::Model::RingPage;
use Ring::Model::Template;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );
    my $content     = $self->content();
    my $form        = $self->form();
    my $user        = $self->user();
    my $uid         = $user->id();
    my $ringpage_id = $form->{ringpage_id};
    if ( not $ringpage_id =~ m{ \A \d+ \z }xms ) {
        return $self->redirect('/u/ringpages');
    }
    my $ringpage_row = Note::Row->new(
        ring_page => {
            id      => $ringpage_id,
            user_id => $uid,
        },
    );

    if ( not $ringpage_row->id() ) {
        return $self->redirect('/u/ringpages');
    }

    my $ringpage_row_data = $ringpage_row->data();

    my $ringpage_fields = decode_json $ringpage_row_data->{fields};

    for my $field ( @{$ringpage_fields} ) {

        my $key     = $field->{name};
        my $value   = $field->{value};
        my $default = $field->{default};

        $ringpage_row_data->{$key} = $value // $default;
    }

    my $template_model     = Ring::Model::Template->new( caller => $self, );
    my $templates          = $template_model->list();
    my $template_name      = $ringpage_row_data->{template};
    my $template_structure = $templates->{$template_name}->{structure};

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ qw{ id button uri }, ],
        where  => { ringpage_id => $ringpage_row->id(), },
    );

    $content->{structure}           = $template_structure;
    $content->{ringpage}            = $ringpage_row_data;
    $content->{ringpage}->{buttons} = $buttons;
    $content->{edit}                = $form->{edit} ? 1 : 0;

    return $self->$next( $param, );
};

sub edit {
    my ( $self, $data, $args ) = @_;
    my $user           = $self->user();
    my $uid            = $user->id();
    my $id             = $args->[0];
    my $ringpage_model = Ring::Model::RingPage->new();

    my $ringpage_row = Note::Row->new(
        ring_page => {
            id      => $id,
            user_id => $uid,
        },
    );

    my $ringpage_row_data = $ringpage_row->data();
    my $ringpage_template = $ringpage_row_data->{template};
    my $ringpage_fields   = decode_json $ringpage_row_data->{fields};

    for my $field ( @{$ringpage_fields} ) {

        my $key = $field->{name};

        $field->{value} = $data->{$key};
    }

    if ($ringpage_model->update(
            fields  => encode_json $ringpage_fields,
            id      => $id,
            user_id => $uid,
        )
        )
    {
        # display confirmation

        my $each_array = each_arrayref [ $self->request()->parameters()->get_all( 'd1-button_id', ), ], [ $self->request()->parameters()->get_all( 'd1-button_text', ), ], [ $self->request()->parameters()->get_all( 'd1-button_link', ), ];
        while ( my ( $button_id, $button_text, $button_link, ) = $each_array->() ) {

            if ( $button_id eq q{} ) {

                next if $button_text eq q{} or $button_link eq q{};

                my $button_row = Note::Row::create(
                    ring_button => {
                        button      => $button_text,
                        ringpage_id => $id,
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

    return;
}

1;
