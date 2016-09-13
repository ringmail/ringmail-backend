package Page::ring::setup::hashtags;

use English '-no_match_vars';
use Moose;
use Note::Param 'get_param';
use Note::SQL::Table 'sqltable';
use Readonly;
use Ring::Model::Category;
use Ring::Model::RingPage;

extends 'Page::ring::user';
extends 'Page::ring::setup::cart';

Readonly my $PAGE_SIZE => 10;

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $where_clause = {

        'ring_hashtag.user_id' => $self->user()->id(),

    };

    $self->content()->{count} = sqltable('ring_hashtag')->count( $where_clause, );

    my ( $page, ) = ( ( $self->form()->{page} // 1 ) =~ m{ \A ( \d+ ) \z }xms, );

    my $page_size = $self->app()->config()->{page_size} // $PAGE_SIZE;

    $self->content()->{hashtags} = sqltable('ring_hashtag')->get(
        select => [
            qw{

                ring_cart.hashtag_id
                ring_cart.transaction_id
                ring_hashtag.directory
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

            [ ring_cart              => qq{ ring_cart.hashtag_id = ring_hashtag.id and ring_cart.user_id = ${ \$self->user()->id() } }, ],
            [ ring_hashtag_directory => 'ring_hashtag_directory.hashtag_id = ring_hashtag.id', ],
            [ ring_page              => qq{ ring_page.id = ring_hashtag.ringpage_id and ring_page.user_id = ${ \$self->user()->id() }}, ],
        ],
        where => $where_clause,
        order => qq{ring_hashtag.hashtag LIMIT ${ \ do { ( $page - 1 ) * $page_size } }, $page_size},
    );

    return $self->SUPER::load( $param, );
}

sub directory_add {
    my ( $self, $form_data, $args, ) = @_;

    my $user            = $self->user();
    my ( $hashtag_id, ) = ( @{$args}, );
    my $user_id         = $user->id();

    my $directory_row = 'Note::Row::find_create'->( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, { ts_created => \'NOW()', }, );

    return;
}

sub directory_remove {
    my ( $self, $form_data, $args, ) = @_;

    my $user            = $self->user();
    my ( $hashtag_id, ) = ( @{$args}, );
    my $user_id         = $user->id();

    my $directory_row = 'Note::Row'->new( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, );

    $directory_row->delete();

    return;
}

1;
