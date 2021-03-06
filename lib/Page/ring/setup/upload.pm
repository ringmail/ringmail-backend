package Page::ring::setup::upload;

use Image::Scale;
use JSON::XS qw{ encode_json decode_json };
use Moose;
use Note::AWS::S3;
use Note::Page;
use Note::Param;
use Ring::Model::RingPage;
use strict;
use warnings;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $user     = $self->user();
    my $form     = $self->form();
    my $response = $self->response();
    my $path     = $self->path();
    my $hostname = $self->hostname();

    my $user_id = $user->id();

    my $uploads = $param->{request}->uploads();

    my @app_path            = @{$path};
    my $app_path_last_index = $#app_path;
    my $upload_type         = $app_path[$app_path_last_index];

    my $field = "f_d2-$upload_type";

    $response->content_type( 'application/json', );

    if ( exists $uploads->{$field} ) {
        my $file = $uploads->{$field}->path();

        my $ringpage_id = $form->{ringpage_id};

        my $ringpage_row = Note::Row->new(
            ring_page => {
                id      => $ringpage_id,
                user_id => $user_id,
            },
        );

        my $template = $ringpage_row->data( 'template', );

        my $fields = decode_json $ringpage_row->data( 'fields', );

        if ( $upload_type eq 'image' ) {

            my $image = 'Image::Scale'->new( $file, );

            $image->resize( { width => 375, }, );

            my $image_height = $image->resized_height();

            if ( $template eq 'v2' ) {

                my ( $buttons, ) = ( $form->{buttons} =~ m{ \A (\d+) \z }xms, );

                if ( $buttons > 0 and $buttons * 90 + 40 > $image_height ) {

                    return encode_json { error => 'size', };
                }

            }

            $image->save_jpeg( $file, );

            for my $field ( @{$fields} ) {

                my $name = $field->{name};

                next if $name ne 'image_height';

                $field->{value} = qq{$image_height};
            }

        }

        my $s3 = 'Note::AWS::S3'->new(
            access_key => $self->app()->config()->{s3_access_key},
            secret_key => $self->app()->config()->{s3_secret_key},
        );
        my $key = join q{/}, ( $hostname =~ m{ ( [\w-]+ ) }xms, ), $user->aws_user_id(), 'ringpage', $ringpage_id, join q{.}, $upload_type, 'jpg';
        $s3->upload(
            file         => $file,
            key          => $key,
            bucket       => 'ringmail1',
            content_type => 'image/jpeg',
            acl_short    => 'public-read',
        );
        my $url = $s3->download_url(
            key    => $key,
            bucket => 'ringmail1',
        );

        # remove '?...' args for public URLs
        $url =~ s{ [?] .* \z }{}xms;

        for my $field ( @{$fields} ) {

            my $name = $field->{name};

            next if $name ne $upload_type;

            $field->{value} = qq{$url};
        }

        my $ringpage_model = 'Ring::Model::RingPage'->new();

        if ($ringpage_model->update(
                fields  => encode_json $fields,
                id      => $ringpage_id,
                user_id => $user_id,
            )
            )
        {
        }

        return encode_json { files => [ { url => qq{$url}, }, ], };
    }
    else {

        return encode_json { error => 'ERROR', };
    }

}

1;
