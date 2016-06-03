package Page::ring::ringpage;

use strict;
use warnings;

use Moose;
use JSON::XS 'decode_json';

use Note::Param;
use Note::SQL::Table 'sqltable';

use Ring::Model::RingPage;

extends 'Page::ring::user';

sub load
{
    my ( $obj, $param ) = get_param( @_ );

    my $ringpage_id = $param->{form}->{ringpage_id};

    my $ringpage_model = Ring::Model::RingPage->new();

    my $ringpage = $ringpage_model->retrieve( id => $ringpage_id, );

    my $buttons = sqltable( 'ring_button', )->get(
        select => [ qw{ button uri }, ],
        where  => { ringpage_id => $ringpage_id, },
    );

    my $ringpage_fields = decode_json $ringpage->{fields};

    for my $field ( @{$ringpage_fields} ) {

        my $key   = $field->{name};
        my $value = $field->{value};

        $ringpage->{$key} = $value;
    }

    $obj->content()->{ringpage} = $ringpage;
    $obj->content()->{ringpage}->{buttons} = $buttons;

	my $tpl = new Note::Template(
		'root' => $obj->root(). '/data/template/'. $ringpage->{'path'},
	);
	my $tmpl;
	my $path = $obj->path();
	if ($path->[-1] eq 'html')
	{
		$obj->response()->content_type('text/html; charset=utf-8');
		$tmpl = $ringpage->{'path'}. '.html';
	}
	elsif ($path->[-1] eq 'css')
	{
		$obj->response()->content_type('text/css; charset=utf-8');
		$tmpl = $ringpage->{'path'}. '.css';
	}
	return $tpl->apply($tmpl, $obj->content());
}

1;
