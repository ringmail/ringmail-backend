package Page::note::rdf::class_browser;
use strict;
use warnings;
no warnings 'uninitialized';

use Moose;
use HTML::Entities;
use URI::Escape;
use Data::Dumper;
use Note::Param;
use Note::Data::RDF_Client;
use Note::XML 'xml';
use Note::HTML 'htable';

extends 'Note::Page';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $ct = $obj->content();
	$ct->{'class_list'} = xml(
		@{htable(
			'array' => 1,
			'fields' => [
				'URI:',
				'Label:',
				'Command:',
			],
			'data' => [
				[1..3],
			],
			'opts' => {
				'class' => 'table table-condensed table-striped table-bordered',
			},
		)},
		'pre', [{},
			0, Dumper($obj->request()),
		],
	);
	return $obj->SUPER::load($param);
}

1;

