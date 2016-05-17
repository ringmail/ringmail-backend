package Page::ring::setup::body_background_image;

use strict;
use warnings;

use Moose;
use POSIX 'strftime';
use JSON::XS;

use Note::Page;
use Note::Param;
use Note::AWS::S3;
use Ring::User;

extends 'Note::Page';
extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my $uploads = $param->{request}->uploads();
    my $response;
    if ( exists $uploads->{'f_d1-body_background_image'} ) {
        my $ul   = $uploads->{'f_d1-body_background_image'};
        my $file = $ul->basename();
        my $path = $ul->path();
        my $s3   = 'Note::AWS::S3'->new(
            access_key => $::app_config->{s3_access_key},
            secret_key => $::app_config->{s3_secret_key},
        );
        my $key = join '/', => 'body_background_image', $obj->user()->id(), $file;
        $s3->upload(
            file         => $path,
            key          => $key,
            bucket       => 'ringmail1',
            content_type => 'image/jpeg',
            expires      => strftime( '%F', gmtime( time() + ( 24 * 3_600 * 1 ) ) ),
        );
        my $url = $s3->download_url(
            key    => $key,
            bucket => 'ringmail1',
        );
        ::log( $url, );
        $response = {
            result => 'ok',
            type   => 'image/jpeg',
        };
    }
    else {
        $response = { result => 'error', };
    }
    $obj->response()->content_type( 'application/json', );
    return encode_json( $response, );
}

1;
