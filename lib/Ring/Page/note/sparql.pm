package Page::note::sparql;
use strict;
use warnings;
no warnings 'uninitialized';

use Moose;
use HTML::Entities;
use URI::Escape;
use Note::Param;
use Note::Data::RDF_Client;
use Note::XML 'xml';
use Note::HTML 'htable';

extends 'Note::Page';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $value = $obj->value();
	my $ct = $obj->content();
	$value->{'endpoint'} ||= 'http://dbpedia.org/sparql';
	$ct->{'endpoint'} = $value->{'endpoint'};
	return $obj->SUPER::load($param);
}

sub get_sparql_query
{
	my ($obj, $data, $args) = @_;
	my $ct = $obj->content();
	if (length($args->[0]))
	{
		my $uri = $args->[0];
		$data->{'sparql'} = <<SPARQL;
SELECT DISTINCT ?a1 ?a2
WHERE {
	 <$uri> ?a1 ?a2.
	 FILTER(
		isIRI(?a2) ||
		langMatches(lang(?a2), "") ||
		langMatches(lang(?a2), "EN")
	)
}
SPARQL
	}
	if (length($args->[1]))
	{
		$data->{'endpoint'} = $args->[1];
	}
	$data->{'endpoint'} ||= 'http://dbpedia.org/sparql';
	$obj->value()->{'endpoint'} = $data->{'endpoint'};
	if (length($data->{'sparql'}))
	{
		$ct->{'query'} = encode_entities($data->{'sparql'});
		my $cl = new Note::Data::RDF_Client(
			'endpoint' => $data->{'endpoint'},
		);
		my $iter = $cl->query(
			'sparql' => $data->{'sparql'},
		);
		my @res = $iter->get_all();
		my @table = ();
		my @heading = ();
		my $first = 0;
		if (scalar @res)
		{
			foreach my $r (@res)
			{
				unless ($first++)
				{
					foreach my $k (sort keys %$r)
					{
						push @heading, $k;
					}
				}
				my @row = ();
				foreach my $k (sort keys %$r)
				{
					my $node = $r->{$k};
					my $rep = '';
					if ($node->is_resource())
					{
						$rep = $obj->link(
							'command' => 'sparql_query',
							'text' => encode_entities($node->uri()),
							'args' => [$node->uri(), $data->{'endpoint'}],
						);
					}
					elsif ($node->is_literal())
					{
						$rep = encode_entities($node->literal_value());
						my $dt = $node->literal_datatype();
						if ($dt)
						{
							$rep .= xml(
								'br', [{}],
								'em', [{}, 0, $dt],
							);
						}
					}
					push @row, $rep;
				}
				push @table, \@row;
			}
			$ct->{'result'} = xml(
				'hr', [{}],
				'div', [{'class' => 'row'},
					'div', [{'class' => 'span10'},
						@{htable(
							'array' => 1,
							'fields' => \@heading,
							'data' => \@table,
							'opts' => {
								'class' => 'table table-condensed table-striped table-bordered',
							},
						)},
					],
				],
			);
		}
	}
}

1;

