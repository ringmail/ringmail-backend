package Page::note::ajax;
use strict;
use warnings;
no warnings 'uninitialized';

use Moose;
use Note::Param;
use JSON::XS;

extends 'Note::Page';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	$obj->response()->content_type('application/json');
	my $data = {};
	foreach my $k (keys %$form)
	{
		eval {
			my $rc = decode_json($form->{$k});
			$data->{$k} = $rc;
		};
	}
	::_log($data);
	return 'Hello';
}

1;

