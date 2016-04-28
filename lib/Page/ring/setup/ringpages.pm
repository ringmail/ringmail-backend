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

    my $template = Ring::Model::Template->new();
    my $templates = $template->get_user_templates( user_id => $user->id(), );

    my @templates;

    if ( scalar @{$templates} ) {
        push @templates, map { [ $ARG->{template} => $ARG->{id}, ]; } @{$templates};
    }
    else {
        push @templates, [ '(No Templates Created)' => 0, ];
    }

    $content->{template_list}             = \@templates;
    $content->{template_sel}              = 0;
    $content->{template_opts}->{id}       = 'template';
    $content->{template_opts}->{onchange} = 'this.form.submit();';

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );
    $content->{ringpages} = $ringpages;

    return $obj->$next( $param, );
};

sub add {
    my ( $obj, $data, $args ) = @_;
    my $user         = $obj->user();
    my $ringpage     = $data->{'ringpage'};
    my $ringlink_url = $data->{ringlink_url};
    my $ringlink     = $data->{ringlink};
    my $template_id  = $data->{template_id};
    my $factory      = Ring::Model::RingPage->new();

    if ( $factory->validate_ringpage( ringpage => $ringpage, ) ) {

        if ( $factory->check_exists( ringpage => $ringpage, ) ) {
            ::log('Dup');
        }
        else {

            my $res = $factory->create(
                ringpage     => $ringpage,
                ringlink_url => $ringlink_url,
                ringlink     => $ringlink,
                template_id  => $template_id,
                user_id      => $user->id(),
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
