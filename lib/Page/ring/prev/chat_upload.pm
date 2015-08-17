package Page::ring::chat_upload;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use POSIX 'strftime';
use URI::Encode 'uri_decode', 'uri_encode';
use Digest::MD5 'md5_hex';

use Note::XML 'xml';
use Note::Page;
use Note::Param;
use Note::S3;

use base 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $uploads = $param->{'request'}->uploads();
	if (exists $uploads->{'userfile'})
	{
		my $ul = $uploads->{'userfile'};
		my $file = $ul->basename();
		my $path = $ul->path();
		my $s3 = new Note::S3();
		my $k = 'chat_upload/'. $file;
		$s3->upload(
			'file' => $path,
			'key' => $k,
			'bucket' => 'ringmail1',
		);
		my $url = $s3->download_url(
			'key' => $k,
			'bucket' => 'ringmail1',
		);
		$obj->response()->content_type('text/plain');
		return $url;
	}
	else
	{
		$obj->response()->status(404);
		return;
	}
	#::_log($res);
}

1;

