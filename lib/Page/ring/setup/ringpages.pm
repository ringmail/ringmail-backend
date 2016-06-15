package Page::ring::setup::ringpages;

use strict;
use warnings;

use Moose;
use JSON::XS qw{ decode_json encode_json };
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use English '-no_match_vars';
use List::MoreUtils 'each_arrayref';

use Note::XML 'xml';
use Note::Param;
use Note::Account qw(account_id transaction tx_type_id);
use Note::Row;

use Ring::User;
use Ring::Model::RingPage;
use Ring::Model::Template;

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

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );
    $content->{ringpages} = $ringpages;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args ) = @_;

    my $user    = $self->user();
    my $factory = Ring::Model::RingPage->new();

    if ( $factory->validate_ringpage( ringpage => $form_data->{ringpage}, ) ) {

        if ( $factory->check_exists( ringpage => $form_data->{ringpage}, ) ) {
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

            my $res = $factory->create(
                fields        => encode_json $template_structure->{fields},
                ringpage      => $form_data->{ringpage},
                template_name => $template_name,
                user_id       => $user->id(),
            );
            if ( defined $res ) {
                ::log( New => $res );

                my $each_array = each_arrayref [ $self->request()->parameters()->get_all( 'd1-button_text', ), ], [ $self->request()->parameters()->get_all( 'd1-button_link', ), ];
                while ( my ( $button_text, $button_link, ) = $each_array->() ) {

                    next if $button_text eq q{} or $button_link eq q{};

                    my $row = Note::Row::create(
                        ring_button => {
                            button      => $button_text,
                            ringpage_id => $res->id(),
                            uri         => $button_link,
                            user_id     => $user->id(),
                        },
                    );
                }

            }
        }
    }

    return;
}

sub remove {
    my ( $self, $form_data, $args ) = @_;

    my $user    = $self->user();
    my $page_id = $args->[0];
    my $factory = Ring::Model::RingPage->new();

    if ($factory->delete(
            id      => $page_id,
            user_id => $user->id(),
        )
        )
    {
        # display confirmation
    }
    else {
        # failed
    }

    return;
}

1;
