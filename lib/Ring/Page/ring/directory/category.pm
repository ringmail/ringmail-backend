package Page::ring::directory::category;
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
	my $cid = $form->{'id'};
	my $cn = $Ring::Category::category_list[$cid];
	$content->{'category_id'} = $cid;
	$content->{'category_name'} = $cn;
	return $obj->SUPER::load($param);
}

1;

