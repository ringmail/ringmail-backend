package Page::ring::setup::body_background_image;

use strict;
use warnings;

use Moose;
use POSIX 'strftime';
use JSON::XS;
use Readonly;
use Math::Random::Secure 'rand';
use String::Random 'random_regex';

use Note::Page;
use Note::Param;
use Note::AWS::S3;
use Ring::User;

extends 'Note::Page';
extends 'Page::ring::user';

Readonly my $DAYS => 24 * 3_600;

sub load {
    my ( @args, ) = @_;

    my $random_string = random_regex( '[A-Za-z0-9]{32}', );

    ::log( $random_string, );

    my ( $obj, $param ) = get_param( @args, );
    my $uploads = $param->{request}->uploads();
    my $response;
    if ( exists $uploads->{'f_d1-body_background_image'} ) {
        my $file = $uploads->{'f_d1-body_background_image'}->path();
        my $s3   = 'Note::AWS::S3'->new(
            access_key => $::app_config->{s3_access_key},
            secret_key => $::app_config->{s3_secret_key},
        );
        my $key = join q{/} => $random_string, 'ringpage', 'body_background_image.jpg';
        $s3->upload(
            file         => $file,
            key          => $key,
            bucket       => 'ringmail1',
            content_type => 'image/jpeg',
            expires      => strftime( '%F', gmtime( time() + ( $DAYS * 1 ) ) ),
            acl_short    => 'public-read',
        );
        my $url = $s3->download_url(
            key    => $key,
            bucket => 'ringmail1',
        );
        ::log( $url, );
        $response = { files => [ { url => qq{$url}, }, ], };
    }
    else {
        $response = { error => 'ERROR', };
    }
    $obj->response()->content_type( 'application/json', );
    return encode_json( $response, );
}

1;
