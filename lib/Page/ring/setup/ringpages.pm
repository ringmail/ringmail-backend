package Page::ring::setup::ringpages;

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
use Note::Account qw(account_id transaction tx_type_id);

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
    my $user    = $obj->user();
    my $factory = Ring::Model::RingPage->new();

    if ( $factory->validate_ringpage( ringpage => $data->{ringpage}, ) ) {

        if ( $factory->check_exists( ringpage => $data->{ringpage}, ) ) {
            ::log('Dup');
        }
        else {

            my $res = $factory->create(
                body_background_color   => $data->{body_background_color},
                body_background_image   => $data->{body_background_image},
                body_header             => $data->{body_header},
                body_text               => $data->{body_text},
                body_text_color         => $data->{body_text_color},
                footer_background_color => $data->{footer_background_color},
                footer_text             => $data->{footer_text},
                footer_text_color       => $data->{footer_text_color},
                header_background_color => $data->{header_background_color},
                header_subtitle         => $data->{header_subtitle},
                header_text_color       => $data->{header_text_color},
                header_title            => $data->{header_title},
                ringpage                => $data->{ringpage},
                template_id             => $data->{template_id},
                user_id                 => $user->id(),
            );
            if ( defined $res ) {
                ::log( New => $res );
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
