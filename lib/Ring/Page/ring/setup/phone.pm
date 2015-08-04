package Page::ring::setup::phone;
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
	my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $user = $obj->user();
	my $phs = $user->get_phones();
	unless (scalar @$phs)
	{
		$user->add_phone();
		$phs = $user->get_phones();
	}
	$content->{'phone_1'} = $phs->[0];
	return $obj->SUPER::load($param);
}

1;

