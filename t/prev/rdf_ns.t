use strict;
use warnings;
use Test::More tests => 7;
use Carp::Always;
use Note::RDF::NS qw(ns_uri ns_iri rdf_ns rdf_prefix ns_match);;

is(rdf_ns('bibo'), 'http://purl.org/ontology/bibo/');
is(rdf_ns('rdfs'), 'http://www.w3.org/2000/01/rdf-schema#');

is(rdf_prefix('bibo'), "PREFIX bibo: <http://purl.org/ontology/bibo/>\n");
is(rdf_prefix('bibo','rdfs'), "PREFIX bibo: <http://purl.org/ontology/bibo/>\nPREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n");

my $v = '';
is(ns_match('http://www.w3.org/2001/XMLSchema#int', \$v), 'xsd');
is($v, 'int');

is (ns_uri('xsd', 'int'), 'http://www.w3.org/2001/XMLSchema#int');

