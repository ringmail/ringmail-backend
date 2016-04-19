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
    my $uid     = $user->id();
    my $factory = Ring::Model::RingPage->new();
    my $ringpages   = $factory->get_user_pages( 'user_id' => $uid, );
    $content->{'ringpages'} = $ringpages;

    my $template = Ring::Model::Template->new();
    my $templates = $template->get_user_templates( 'user_id' => $uid, );

    ::log( $templates, );

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

    ::log( $content->{template_list}, );

    return $obj->$next( $param, );
};

sub add {
    my ( $obj, $data, $args ) = @_;
    my $user    = $obj->user();
    my $uid     = $user->id();
    my $page    = $data->{'page'};
    my $factory = Ring::Model::RingPage->new();

    if ( $factory->validate_page( page => $page, ) ) {

        if ( $factory->check_exists( page => $page, ) ) {
            ::log('Dup');
        }
        else {

            my $res = $factory->create(
                page    => $page,
                user_id => $uid,
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
    my $uid     = $user->id();
    my $page_id = $args->[0];
    my $factory = Ring::Model::RingPage->new();
    if ($factory->delete(
            'id'      => $page_id,
            'user_id' => $uid,
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
