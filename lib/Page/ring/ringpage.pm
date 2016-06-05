package Page::ring::ringpage;

use strict;
use warnings;

use Moose;
use JSON::XS 'decode_json';

use Note::Param;
use Note::SQL::Table 'sqltable';

use Ring::Model::RingPage;
use Ring::Model::Template;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $ringpage_id     = $param->{form}->{ringpage_id};
    my $ringpage_model  = Ring::Model::RingPage->new();
    my $ringpage        = $ringpage_model->retrieve( ringpage_id => $ringpage_id, );
    my $ringpage_fields = decode_json $ringpage->{fields};

    for my $field ( @{$ringpage_fields} ) {

        my $key   = $field->{name};
        my $value = $field->{value};

        $ringpage->{$key} = $value;
    }

    $self->content()->{ringpage} = $ringpage;

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ qw{ button uri }, ],
        where  => { ringpage_id => $ringpage_id, },
    );

    $self->content()->{ringpage}->{buttons} = $buttons;

    my $template_model = Ring::Model::Template->new( caller => $self, );
    my $templates      = $template_model->list();
    my $template_name  = $ringpage->{template};

    my $uri_path = $self->path();
    my $template_filename;
    if ( $uri_path->[-1] eq 'html' ) {
        $self->response()->content_type('text/html; charset=utf-8');
        $template_filename = $templates->{$template_name}->{path} . '.html';
    }
    elsif ( $uri_path->[-1] eq 'css' ) {
        $self->response()->content_type('text/css; charset=utf-8');
        $template_filename = $templates->{$template_name}->{path} . '.css';
    }

    my $tpl = Note::Template->new( root => $self->root() . '/data/template/' . $templates->{$template_name}->{path}, );

    return $tpl->apply( $template_filename, $self->content(), );
}

1;
