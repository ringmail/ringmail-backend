package Page::ring::setup::processing;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;

extends 'Page::ring::user';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $content = $obj->content();
	my $sd = $obj->session();
	if (defined $sd->{'payment_attempt'})
	{
		my $rc = new Note::Row('payment_attempt' => $sd->{'payment_attempt'});
		if ($rc->id())
		{
			if ($rc->data('result') ne 'processing')
			{
				return $obj->redirect('/u/settings');
			}
		}
	}
	unless (exists $sd->{'payment_attempt'})
	{
		return $obj->redirect('/u/settings');
	}
	::_log($sd);
	#my $user = $obj->user();
	return $obj->SUPER::load($param);
}

1;

