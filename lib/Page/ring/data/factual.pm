package Page::ring::data::factual;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use JSON::XS;
use Math::Round 'nearest';

use Note::XML 'xml';
use Note::Page;
use Note::Param;
use Note::Factual;

use Ring::Category;

use base 'Note::Page';

no warnings 'uninitialized';

sub build_url
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $sd = $obj->session();
	my $path;
	my $qry;
	if ($form->{'query'} eq 'category')
	{
		my $cid = $form->{'category_id'};
		my $cn = $Ring::Category::category_list[$cid];
		my $cd = $Ring::Category::category_hash{$cn};
		my $sdir = $sd->{'directory'};
		my $lat = $sdir->{'lat'};
		my $lon = $sdir->{'lon'};
		my $fcn = $cd->{'factual'};
		my $fcat = $Note::Factual::category_hash{$fcn}->{'category_id'};
		$path = '/t/places';
		$qry = {
			'select' => 'longitude,latitude,name,address,tel,website,factual_id,postcode',
			'limit' => 50,
			'filters' => qq|{"category_ids":{"\$includes":$fcat}}|,
			'geo' => qq|{"\$circle":{"\$center":[$lat,$lon],"\$meters":2500}}|,
		};
	}
	return $obj->url(
		'proto' => 'http',
		'host' => 'api.v3.factual.com',
		'port' => 80,
		'path' => $path,
		'query' => $qry,
	);
}

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $res = '';
	my $ft = new Note::Factual;
	my $url = $obj->build_url();
#	::_log($url);
	$res = $ft->query(
		'url' => $url,
	);
#	if (defined $res)
#	{
#		::_log(decode_json($res));
#	}
	$obj->response()->content_type('application/json');
	return $res;
}

1;

