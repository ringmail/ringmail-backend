package Page::ring::app::chat_upload;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use POSIX 'strftime';
use URI::Encode 'uri_decode', 'uri_encode';
use Digest::MD5 'md5_hex';
use JSON::XS;

use Note::XML 'xml';
use Note::Page;
use Note::Param;
use Note::AWS::S3;

use base 'Note::Page';
use vars qw(%MIME_OK);

no warnings 'uninitialized';

our %MIME_OK = map {$_ => 1} qw(
	image/jpeg
	image/png
	video/mp4
);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $uploads = $param->{'request'}->uploads();
	my $res;
	if (exists $uploads->{'userfile'})
	{
		my $ul = $uploads->{'userfile'};
		my $file = $ul->basename();
		my $uuid = $file;
		$uuid =~ s/\..*$//;
		my $path = $ul->path();
		my $s3 = new Note::AWS::S3(
			'access_key' => $main::app_config->{'s3_access_key'},
			'secret_key' => $main::app_config->{'s3_secret_key'},
		);
		my $k = 'chat_upload/'. $file;
		my $ct = 'application/data';
		if ($param->{'form'}->{'mime_type'})
		{
			my $nct = lc($param->{'form'}->{'mime_type'});
			if ($MIME_OK{$ct})
			{
				$ct = $nct;
			}
		}
		$s3->upload(
			'file' => $path,
			'key' => $k,
			'bucket' => 'ringmail1',
			'content_type' => $ct,
			'expires' => strftime("%F", gmtime(time() + (24 * 3600 * 7))),
		);
		my $url = $s3->download_url(
			'key' => $k,
			'bucket' => 'ringmail1',
		);
		$res = {
			'result' => 'ok',
			'uuid' => $uuid,
			'type' => $ct,
			'url' => "$url",
		};
	}
	else
	{
		$res = {
			'result' => 'error',
		};
	}
	::log($res);
	$obj->response()->content_type('application/json');
	return encode_json($res);
}

1;

