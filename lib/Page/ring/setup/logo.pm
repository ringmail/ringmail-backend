package Page::ring::setup::logo;

use strict;
use warnings;

use Moose;
use POSIX 'strftime';
use JSON::XS;
use Readonly;

use Note::Page;
use Note::Param;
use Note::AWS::S3;
use Ring::User;

extends 'Note::Page';
extends 'Page::ring::user';

Readonly my $DAYS => 24 * 3_600;

sub load {
    my ( @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my $user          = $obj->user();
    my ( $hostname, ) = ( $::app_config->{www_domain} =~ m{ ( [\w-]+ ) }xms, );
    my $uploads       = $param->{request}->uploads();
    my $content;
    ::log( $user->aws_user_id(), );
    ::log( $hostname, );
    if ( exists $uploads->{'f_d1-logo'} ) {
        my $file = $uploads->{'f_d1-logo'}->path();
        my $s3   = 'Note::AWS::S3'->new(
            access_key => $::app_config->{s3_access_key},
            secret_key => $::app_config->{s3_secret_key},
        );
        my $key = join q{/}, $hostname, $user->aws_user_id(), 'ringpage', 'logo.jpg';
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
        $content = { files => [ { url => qq{$url}, }, ], };
    }
    else {
        $content = { error => 'ERROR', };
    }
    my $response = $obj->response();
    $response->content_type( 'application/json', );
    return encode_json( $content, );
}

1;
