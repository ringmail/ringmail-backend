package Page::ring::setup::ringpages;

use English '-no_match_vars';
use HTML::Escape 'escape_html';
use JSON::XS 'encode_json';
use List::MoreUtils 'each_arrayref';
use Moose;
use Note::Param;
use Regexp::Common 'whitespace';
use Ring::Model::Hashtag;
use Ring::Model::RingPage;
use Ring::Model::Template;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();
    my $form    = $self->form();
    my $user    = $self->user();

    my $user_id = $user->id();

    my $ringpage_model = Ring::Model::RingPage->new();
    my $ringpages = $ringpage_model->list( user_id => $user_id, );

    my $template = Ring::Model::Template->new( caller => $self, );
    my $templates = $template->list();

    my @templates;

    push @templates, map { [ $templates->{$ARG}->{title} => $ARG, ]; } sort keys $templates;

    $content->{ringpages}     = $ringpages;
    $content->{template_list} = \@templates;

    return $self->SUPER::load( $param, );
}

sub add {
    my ( $self, $form_data, $args, ) = @_;

    my ( $ringpage_name, ) = ( escape_html( $RE{ws}{crop}->subs( $form_data->{ringpage_name} ) ) =~ m{ \A ( [[:alpha:][:digit:][:punct:][:space:]]+ ) \z }xms, );
    my ( $template_name, ) = ( escape_html( $RE{ws}{crop}->subs( $form_data->{template_name} ) ) =~ m{ \A ( \w+ ) \z }xms, );
    my ( $hashtag_id, )    = ( escape_html( $RE{ws}{crop}->subs( $form_data->{hashtag_id} // q{} ) ) =~ m{ \A ( \d+ ) \z }xms, );

    if ( defined $ringpage_name ) {

        my $user = $self->user();

        my $template_model = Ring::Model::Template->new( caller => $self, );
        my $templates = $template_model->list();

        my $template_structure = $templates->{$template_name}->{structure};

        for my $field ( @{ $template_structure->{fields} } ) {

            my $name       = $field->{name};
            my $form_value = defined( $form_data->{$name} ) ? escape_html( $RE{ws}{crop}->subs( $form_data->{$name} ) ) : undef;
            my $default    = $field->{default};

            $field->{value} = $form_value // $default;
        }

        my $ringpage_model = Ring::Model::RingPage->new();

        my $ringpage = $ringpage_model->create(
            fields        => encode_json $template_structure->{fields},
            ringpage      => $ringpage_name,
            template_name => $template_name,
            user_id       => $user->id(),
        );
        if ( defined $ringpage ) {

            my $each_array = each_arrayref [ 'Call', ], [ 'ring://call/' . $user->row()->data( 'login', ), ];
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
    else {

        $self->form()->{ringpage_name} = $form_data->{ringpage_name};
        $self->value()->{error}        = "RingPage name '$form_data->{ringpage_name}' is invalid.";

    }

    return;
}

sub remove {
    my ( $self, $form_data, $args, ) = @_;

    my $user = $self->user();

    my $user_id = $user->id();

    my ( $ringpage_id, ) = @{$args};

    if ( $ringpage_id =~ m{ \A ( \d+ ) \z }xms ) {

        my $ringpage_model = Ring::Model::RingPage->new();

        if ($ringpage_model->remove(
                id      => $ringpage_id,
                user_id => $user_id,
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
