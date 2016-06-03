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

around load => sub {
    my ( $next, @args, ) = @_;
    my ( $obj, $param ) = get_param( @args, );

    #my $form = $obj->form();
    #::_log($form);
    my $content = $obj->content();
    my $user    = $obj->user();

    my $template  = Ring::Model::Template->new();
    my $templates = $template->list();

    my @templates;

    if ( scalar @{$templates} ) {
        push @templates, map { [ $ARG->{template} => $ARG->{id}, ]; } @{$templates};
    }
    else {
        push @templates, [ '(No Templates Created)' => 0, ];
    }

    $content->{template_list}       = \@templates;
    $content->{template_sel}        = 0;
    $content->{template_opts}->{id} = 'template';

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );
    $content->{ringpages} = $ringpages;

    return $obj->$next( $param, );
};

sub add {
    my ( $obj, $data, $args ) = @_;

    ::log( $data, );

    my $user    = $obj->user();
    my $factory = Ring::Model::RingPage->new();

    if ( $factory->validate_ringpage( ringpage => $data->{ringpage}, ) ) {

        if ( $factory->check_exists( ringpage => $data->{ringpage}, ) ) {
            ::log('Dup');
        }
        else {

            my $template = Note::Row->new( ring_template => { id => $data->{template_id}, }, );
            my $structure = decode_json $template->data( 'structure', );

            for my $field ( @{ $structure->{fields} } ) {
                my $name = $field->{name};

                $field->{value} = $data->{$name};
            }

            ::log( $structure, );

            my $res = $factory->create(
                fields      => encode_json $structure->{fields},
                ringpage    => $data->{ringpage},
                template_id => $data->{template_id},
                user_id     => $user->id(),
            );
            if ( defined $res ) {
                ::log( New => $res );

                my $each_array = each_arrayref [ $obj->request()->parameters()->get_all( 'd1-button_text', ), ], [ $obj->request()->parameters()->get_all( 'd1-button_link', ), ];
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
    my ( $obj, $data, $args ) = @_;
    my $user    = $obj->user();
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
