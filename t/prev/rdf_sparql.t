use strict;
use warnings;
use Test::More tests => 6;
use Data::Dumper;
use Note::RDF::NS;
use RDF::Trine ('iri', 'statement', 'literal', 'blank');
use Carp::Always;

no warnings 'once';

BEGIN: {
	$Note::Config::File = '/home/note/run/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Note::RDF::Sparql');
}

my $baseuri = 'http://tempuri.org/';
my $ctxt = iri($baseuri. 'test');
my $subj = iri($baseuri. 'inst/subj_1');

my $rsrc = new Note::RDF::Sparql(
	'context' => $ctxt,
	'endpoint' => 'http://atellix:83jd5cb38xhm9@localhost:8890/sparql-auth',
	'subject' => $subj,
);

my $iter = $rsrc->get_statements(undef, undef, undef, $rsrc->context());
while (my $v = $iter->next())
{
	print Dumper($v);
}
$rsrc->delete();

$rsrc->add(iri($baseuri. 'attr/field_1'), 'Value1');
$rsrc->add(iri($baseuri. 'attr/field_2'), 'Value2');
$iter = $rsrc->get_statements(undef, undef, undef, $rsrc->context());
my $model = new RDF::Trine::Model();
$model->add_iterator($iter);
my $hr = $model->as_hashref();
#print Dumper($hr);
my $okrdf;
$okrdf = {
	'http://tempuri.org/inst/subj_1' => {
		'http://tempuri.org/attr/field_2' => [
			{
				'value' => 'Value2',
				'type' => 'literal',
				'datatype' => 'http://www.w3.org/2001/XMLSchema#string'
			},
		],
			'http://tempuri.org/attr/field_1' => [
			{
				'value' => 'Value1',
				'type' => 'literal',
				'datatype' => 'http://www.w3.org/2001/XMLSchema#string'
			},
		],
	},
};
is_deeply($hr, $okrdf, 'RDF create model 1');

$rsrc->remove(iri($baseuri. 'attr/field_1'), 'Value1');
$okrdf = {
	'http://tempuri.org/inst/subj_1' => {
		'http://tempuri.org/attr/field_2' => [
			{
				'value' => 'Value2',
				'type' => 'literal',
				'datatype' => 'http://www.w3.org/2001/XMLSchema#string'
			},
		],
	},
};
$iter = $rsrc->get_statements(undef, undef, undef, $rsrc->context());
$model = new RDF::Trine::Model();
$model->add_iterator($iter);
$hr = $model->as_hashref();
is_deeply($hr, $okrdf, 'RDF remove statement 1');

$rsrc->set(iri($baseuri. 'attr/field_2'), 'Value3');
$okrdf = {
	'http://tempuri.org/inst/subj_1' => {
		'http://tempuri.org/attr/field_2' => [
			{
				'value' => 'Value3',
				'type' => 'literal',
				'datatype' => 'http://www.w3.org/2001/XMLSchema#string'
			},
		],
	},
};
$iter = $rsrc->get_statements(undef, undef, undef, $rsrc->context());
$model = new RDF::Trine::Model();
$model->add_iterator($iter);
$hr = $model->as_hashref();
is_deeply($hr, $okrdf, 'RDF set statement 1');

$rsrc->delete();
$okrdf = {};
$iter = $rsrc->get_statements(undef, undef, undef, $rsrc->context());
$model = new RDF::Trine::Model();
$model->add_iterator($iter);
$hr = $model->as_hashref();
is_deeply($hr, $okrdf, 'RDF delete 1');

