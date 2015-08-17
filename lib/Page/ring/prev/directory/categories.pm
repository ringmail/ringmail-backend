package Page::ring::directory::categories;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use POSIX 'strftime';
use URI::Encode 'uri_decode', 'uri_encode';
use Digest::MD5 'md5_hex';
use HTML::Entities 'encode_entities';

use Note::XML 'xml';
use Note::Page;
use Note::Param;

use Ring::Category;

use base 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	my $sd = $obj->session();
	#::_log($form);
	if (defined($form->{'la'}) && defined($form->{'lo'}))
	{
		$sd->{'directory'}->{'lat'} = $form->{'la'};
		$sd->{'directory'}->{'lon'} = $form->{'lo'};
		$obj->session_write();
	}
	my $cats = [];
	foreach my $i (0..$#Ring::Category::category_list)
	{
		my $c = $Ring::Category::category_list[$i];
		my $cd = $Ring::Category::category_hash{$c};
		push @$cats, {'name' => encode_entities($c), 'id' => $i, 'icon' => $cd->{'icon'}};
	}
	$content->{'categories'} = $cats;
	return $obj->SUPER::load($param);
}

1;

