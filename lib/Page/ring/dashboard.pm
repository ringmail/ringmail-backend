package Page::ring::dashboard;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use Regexp::Common 'net';

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
	my $val = $obj->value();
	my $user = $obj->user();
	my $rc = new Note::Row(
		'ring_user' => {'id' => $user->id()},
	);
	$content->{'login'} = $rc->data('login');
	return $obj->SUPER::load($param);
}

# TODO: move to utils class
sub format_phone
{
	my ($obj, $data) = @_;
	if ($data->{'did_code'} eq '1')
	{
		my $ph = $data->{'did_number'};
		$ph =~ s/(...)(...)(....)/($1) $2-$3/;
		return $ph;
	}
	else
	{
		return '+'. $data->{'did_code'}. $data->{'did_number'};
	}
}

1;

