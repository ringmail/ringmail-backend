package Page::ring::setup::admin::directory;

use Moose 'extends';
use Note::Param 'get_param';
use Note::SQL::Table 'sqltable';

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $content = $self->content();
    my $form    = $self->form();

    my ( $page, ) = ( $form->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $offset = ( $page * 10 ) - 10;

    my $count = sqltable('ring_hashtag')->count();

    my $hashtags = sqltable('ring_hashtag')->get(
        select => [
            qw{

                ring_cart.hashtag_id
                ring_cart.transaction_id
                ring_hashtag.hashtag
                ring_hashtag.id
                ring_hashtag.ringpage_id
                ring_hashtag.target_url
                ring_hashtag_directory.ts_directory
                ring_page.ringpage

                },
            'ring_hashtag_directory.id AS directory_id',
        ],
        join_left => [

            [ ring_cart              => 'ring_cart.hashtag_id = ring_hashtag.id', ],
            [ ring_hashtag_directory => 'ring_hashtag_directory.hashtag_id = ring_hashtag.id', ],
            [ ring_page              => 'ring_page.id = ring_hashtag.ringpage_id', ],

        ],
        order => qq{ring_hashtag.id LIMIT $offset, 10},
    );

    $content->{count}    = $count;
    $content->{hashtags} = $hashtags;

    return $self->SUPER::load( $param, );
}

1;
