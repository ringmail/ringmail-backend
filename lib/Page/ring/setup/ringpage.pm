package Page::ring::setup::ringpage;

use constant::boolean;
use Email::Valid;
use English '-no_match_vars';
use HTML::Escape 'escape_html';
use JSON::XS qw{ encode_json decode_json };
use List::MoreUtils qw{ each_arrayref first_value };
use Moose;
use Note::Param;
use Note::SQL::Table 'sqltable';
use Regexp::Common 'URI';
use Regexp::Common 'whitespace';
use Ring::Model::RingPage;
use Ring::Model::Template;

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
        select => [ qw{ id button uri position }, ],
        where  => { ringpage_id => $ringpage_row->id(), },
        order  => 'id',
    );

    for my $button ( @{$buttons} ) {

        my ( $uri, $position, ) = ( $button->{uri}, $button->{position}, );

        if ( $position > 1 ) {

            my ( @uri, ) = split qr{/}xms, $uri;

            $button->{value} = $uri[-1];

        }
        else {

            $button->{value} = $uri;

        }
    }

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
        my $form_value = $form_data->{$name};

        if ( defined $field->{internal} and $field->{internal} == TRUE ) {

            $field->{value} = $ringpage_fields{$name};

        }
        elsif ( defined $form_value ) {

            $form_value = escape_html( $RE{ws}{crop}->subs( $form_data->{$name} ) );

            if ( defined $field->{text_type} and $field->{text_type} eq 'url' ) {

                if ( not $form_value =~ m{ \A http(s)?:// }xmsi and length $form_value > 0 ) {

                    $form_value = "http://$form_value";

                    ( $form_value, ) = ( $form_value =~ m{ ( $RE{URI} ) }xms, );

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

        my ( @button_links, );

        my $button_links_iterator = each_arrayref [ $self->request()->parameters()->get_all( 'd2-button_link', ), ], [ $self->request()->parameters()->get_all( 'd2-button_type', ), ], [ 1 .. @{ [ $self->request()->parameters()->get_all( 'd2-button_link', ) ] }, ];
        while ( my ( $button_link, $button_type, $button_position, ) = $button_links_iterator->() ) {

            next if not defined $button_link;
            next if not defined $button_type;

            next if not defined $button_position;

            next if not length $button_link > 0;
            next if not length $button_type > 0;

            next if not( $button_position > 0 );

            push @button_links,
                {
                button_link     => $button_link,
                button_type     => $button_type,
                button_position => $button_position,
                };

        }

        for my $button_link (@button_links) {

            my ( $button_position, $value, $button_type, ) = ( $button_link->{button_position}, $button_link->{button_link}, $button_link->{button_type}, );

            if ( $button_position > 1 ) {

                my $email = 'Email::Valid'->address(
                    -address  => $value,
                    -mxcheck  => TRUE,
                    -tldcheck => TRUE,
                );

                if ( defined $email ) {

                    $button_link->{button_link} = "ring://$button_type/$email";

                    ( $button_link->{button_link}, ) = ( $button_link->{button_link} =~ m{ ( $RE{URI}{HTTP}{-scheme => 'ring'} ) }xms, );

                }
                else {

                    undef $button_link->{button_link};

                }

            }
            else {

                if ( not $button_link->{button_link} =~ m{ \A http(s)?:// }xmsi and length $button_link->{button_link} > 0 ) {

                    $button_link->{button_link} = "http://$button_link->{button_link}";

                }

                ( $button_link->{button_link}, ) = ( $button_link->{button_link} =~ m{ ( $RE{URI}{HTTP} (?:\#\w+)? ) }xms, );

            }

            if ( not defined $button_link->{button_link} ) {

                $button_link = ();

            }

        }

        my ( $button_link, ) = ( @button_links, );

        my $buttons_iterator = each_arrayref [ escape_html first_value { length > 0; } $self->request()->parameters()->get_all( 'd2-button_id', ), ], [ escape_html first_value { length > 0; } $self->request()->parameters()->get_all( 'd2-button_text', ), ];
        while ( my ( $button_id, $button_text, ) = $buttons_iterator->() ) {

            if ( not defined $button_id or $button_id eq q{} ) {

                next if not defined $button_text or $button_text eq q{} or not defined $button_link;

                my $button_row = Note::Row::create(
                    ring_button => {
                        button      => $button_text,
                        position    => $button_link->{button_position},
                        ringpage_id => $ringpage_id,
                        uri         => $button_link->{button_link},
                        user_id     => $user->id(),
                    },
                );

            }

            else {

                my $button_row = Note::Row->new( ring_button => $button_id, );

                if ( $button_text eq q{} or not defined $button_link ) {

                    $button_row->delete();

                }

                else {

                    $button_row->update(
                        {   button   => $button_text,
                            position => $button_link->{button_position},
                            uri      => $button_link->{button_link},
                        },
                    );

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
