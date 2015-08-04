package Page::atx::local::city;
use strict;
use warnings;

use Moose;
use HTML::Entities;
use URI::Escape;
use Data::Dumper;
use Scalar::Util ('blessed', 'reftype');
use RDF::Trine ('iri', 'statement', 'literal');
use RDF::Trine::Store;
use RDF::Trine::Model;

use Note::Page;
use Note::Param;
use Note::XML 'xml';
use Note::HTML 'htable';
use Note::RDF::NS ('ns_iri', 'ns_uri', 'rdf_ns');
use Note::RDF::Sparql;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $value = $obj->value();
	my $ct = $obj->content();
	my $atxrec = $obj->data()->{'atx'};
	my $item = $atxrec->{'item'};
	my $atxdb = $obj->storage()->{'atx_virtuoso_1'};
	my $atx = $atxdb->context()->uri_value();
	my %attrmap = (
		ns_uri('rdfs', 'label') => 'label',
		"${atx}attr-local-city-region" => ['region', {
			"${atx}attr-local-region-code" => 'code',
		}],
	);
	$ct->{'atx'} = $obj->get_resource(
		'item_iri' => iri($item),
		'attr_map' => \%attrmap,
	);
	return $obj->SUPER::load($param);
}

sub get_resource
{
	my ($obj, $param) = get_param(@_);
	my $itemiri = $param->{'item_iri'};
	my $attrmap = $param->{'attr_map'};
	my $atxdb = $obj->storage()->{'atx_virtuoso_1'};
	my $atx = $atxdb->context()->uri_value();
	my $iterator = $atxdb->build_sparql(
		'query' => 1,
		'prefix' => {
			'atx' => $atx,
		},
		'where' => [
			[$itemiri, '?attr', '?val'],
		],
	);
	my $atxpage = {};
	while (my $r = $iterator->next())
	{
		my $attr = $r->{'attr'}->uri_value();
		if (exists $attrmap->{$attr})
		{
			my $dk = $attrmap->{$attr};
			if (ref($dk) && reftype($dk) eq 'ARRAY')
			{
				# recursive
				my $dv = $r->{'val'};
				if ($dv->is_resource())
				{
					$atxpage->{$dk->[0]} = $obj->get_resource(
						'item_iri' => $dv,
						'attr_map' => $dk->[1],
					);
				}
			}
			else
			{
				my $dv = $r->{'val'};
				if ($dv->is_literal())
				{
					$atxpage->{$dk} = $dv->literal_value();
				}
				elsif ($dv->is_resource())
				{
					$atxpage->{$dk} = $dv->uri_value();
				}
			}
		}
	}
	return $atxpage;
}

1;

