use strict;
use warnings;
use Test::More tests => 6;
use Carp::Always;
use Data::Dumper;
use Note::RDF::NS;
use RDF::Trine ('iri', 'statement', 'literal', 'blank');

no warnings 'once';

BEGIN: {
	$Note::Config::File = '/home/note/run/cfg/note.cfg';
	use_ok('Note::Config');
	use_ok('Note::RDF::Resource');
}

my $sto = $Note::Config::Data->storage()->{'atx_virtuoso_1'};
my $baseuri = 'http://tempuri.org/';
my $ctxt = iri($baseuri. 'test');
my $subj = iri($baseuri. 'inst/subj_1');

my $rsrc = new Note::RDF::Resource(
	'context' => $ctxt,
	'storage' => $sto,
	'subject' => $subj,
);

my $iter = $rsrc->model_storage()->get_statements(undef, undef, undef, $rsrc->context());
while (my $v = $iter->next())
{
	$rsrc->model_storage()->remove_statements($v->subject(), $v->predicate(), $v->object(), $rsrc->context());
}

$rsrc->add(iri($baseuri. 'attr/field_1'), 'Value1');
$rsrc->add(iri($baseuri. 'attr/field_2'), 'Value2');
$iter = $rsrc->model_storage()->get_statements(undef, undef, undef, $rsrc->context());
my $model = new RDF::Trine::Model();
$model->add_iterator($iter);
my $hr = $model->as_hashref();
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
$iter = $rsrc->model_storage()->get_statements(undef, undef, undef, $rsrc->context());
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
$iter = $rsrc->model_storage()->get_statements(undef, undef, undef, $rsrc->context());
$model = new RDF::Trine::Model();
$model->add_iterator($iter);
$hr = $model->as_hashref();
is_deeply($hr, $okrdf, 'RDF set statement 1');

$rsrc->delete();
$okrdf = {};
$iter = $rsrc->model_storage()->get_statements(undef, undef, undef, $rsrc->context());
$model = new RDF::Trine::Model();
$model->add_iterator($iter);
$hr = $model->as_hashref();
is_deeply($hr, $okrdf, 'RDF delete 1');

