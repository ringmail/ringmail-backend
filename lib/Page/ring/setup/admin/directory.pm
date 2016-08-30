package Page::ring::setup::admin::directory;

use English '-no_match_vars';
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

sub approve {
    my ( $self, $form_data, $args, ) = @_;

    my $form    = $self->form();
    my $request = $self->request();

    my $search = $form_data->{search};

    my $where_clause = {};

    if ( defined $search ) {

        $where_clause = { 'ring_hashtag.hashtag' => [ like => qq{%$search%}, ], };

    }

    my ( $page, ) = ( $form->{page} // 1 =~ m{ \A \d+ \z }xms, );

    my $offset = ( $page * 10 ) - 10;

    my $count = defined $search ? sqltable('ring_hashtag')->count( hashtag => [ like => qq{%$search%}, ], ) : sqltable('ring_hashtag')->count();

    my $hashtags = sqltable('ring_hashtag')->get(
        select => [
            qw{

                ring_hashtag.id
                ring_hashtag.hashtag
                ring_hashtag_directory.hashtag_id

                },
        ],
        join_left => [

            [ ring_hashtag_directory => 'ring_hashtag_directory.hashtag_id = ring_hashtag.id AND ring_hashtag_directory.ts_directory IS NOT NULL', ],

        ],
        where => $where_clause,
        order => defined $search ? q{ring_hashtag.id} : qq{ring_hashtag.id LIMIT $offset, 10},
    );

    my @hashtags_approved = map { $ARG->{id} + 0 } grep { defined $ARG->{hashtag_id} and $ARG->{id} == $ARG->{hashtag_id} } @{$hashtags};
    my @hashtags_checked = map { $ARG + 0 } $request->parameters()->get_all( 'd2-hashtag_id', );

    my %hashtags_approved;
    @hashtags_approved{@hashtags_approved} = undef;

    my %hashtags_checked;
    @hashtags_checked{@hashtags_checked} = undef;

    for my $hashtag_id (@hashtags_checked) {
        delete $hashtags_approved{$hashtag_id};
    }

    for my $hashtag_id (@hashtags_approved) {
        delete $hashtags_checked{$hashtag_id};
    }

    my @delete = keys %hashtags_approved;
    my @add    = keys %hashtags_checked;

    for my $hashtag_id (@delete) {

        my $row = 'Note::Row'->new( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, );

        if ( defined $row->id() ) {

            $row->update( { ts_directory => undef, }, );

        }

    }

    for my $hashtag_id (@add) {

        my $row = 'Note::Row::find_create'->( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, { ts_created => \'NOW()', }, );

        if ( defined $row->id() ) {

            $row->update( { ts_directory => \'NOW()', }, );

        }

    }

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => { page => $page, }, ), );
}

1;
