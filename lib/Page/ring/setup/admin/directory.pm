package Page::ring::setup::admin::directory;

use English '-no_match_vars';
use Moose 'extends';
use Note::Param 'get_param';
use Note::SQL::Table 'sqltable';
use Ring::Model::Category;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my $form = $self->form();

    my $where_clause = {};

    my ( $search, ) = ( ( $form->{search} // q{} ) =~ m{ \A ( \w+ ) \z }xms, );

    if ( defined $search ) {

        $where_clause->{hashtag} = [ like => qq{%$search%}, ];

    }

    my ( $category_id, ) = ( ( $form->{category_id} // q{} ) =~ m{ \A ( \d+ ) \z }xms, );

    if ( defined $category_id ) {

        $where_clause->{'ring_hashtag.category_id'} = $category_id;

    }

    my ( $page, ) = ( ( $form->{page} // 1 ) =~ m{ \A ( \d+ ) \z }xms, );

    my $offset = ( $page * 10 ) - 10;

    my $hashtags = sqltable('ring_hashtag')->get(
        select => [
            qw{

                ring_cart.hashtag_id
                ring_cart.transaction_id
                ring_category.category
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
        table     => [ qw{ ring_hashtag ring_category }, ],
        join      => [ 'ring_category.id = ring_hashtag.category_id', ],
        join_left => [

            [ ring_cart              => 'ring_cart.hashtag_id = ring_hashtag.id', ],
            [ ring_hashtag_directory => 'ring_hashtag_directory.hashtag_id = ring_hashtag.id', ],
            [ ring_page              => 'ring_page.id = ring_hashtag.ringpage_id', ],

        ],
        where => $where_clause,
        order => qq{ring_hashtag.id LIMIT $offset, 10},
    );

    my $count = sqltable('ring_hashtag')->count( $where_clause, );

    my $category_model = 'Ring::Model::Category'->new();
    my $categories     = $category_model->list();

    my $content = $self->content();

    $content->{category_list} = [ map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories}, ];
    $content->{count}         = $count;
    $content->{hashtags}      = $hashtags;

    return $self->SUPER::load( $param, );
}

sub approve {
    my ( $self, $form_data, $args, ) = @_;

    my $form = $self->form();

    my $where_clause = {};

    my ( $search, ) = ( ( $form_data->{search} // q{} ) =~ m{ \A ( \w+ ) \z }xms, );

    if ( defined $search ) {

        $where_clause->{hashtag} = [ like => qq{%$search%}, ];

    }

    my ( $category_id, ) = ( ( $form_data->{category_id} // q{} ) =~ m{ \A ( \d+ ) \z }xms, );

    if ( defined $category_id ) {

        $where_clause->{'ring_hashtag.category_id'} = $category_id;

    }

    my ( $page, ) = ( ( $form->{page} // 1 ) =~ m{ \A ( \d+ ) \z }xms, );

    my $offset = ( $page * 10 ) - 10;

    my $hashtags = sqltable('ring_hashtag')->get(
        select => [
            qw{

                ring_cart.hashtag_id
                ring_cart.transaction_id
                ring_category.category
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
        table     => [ qw{ ring_hashtag ring_category }, ],
        join      => [ 'ring_category.id = ring_hashtag.category_id', ],
        join_left => [

            [ ring_cart              => 'ring_cart.hashtag_id = ring_hashtag.id', ],
            [ ring_hashtag_directory => 'ring_hashtag_directory.hashtag_id = ring_hashtag.id', ],
            [ ring_page              => 'ring_page.id = ring_hashtag.ringpage_id', ],

        ],
        where => $where_clause,
        order => qq{ring_hashtag.id LIMIT $offset, 10},
    );

    my $request = $self->request();

    my @hashtags_approved = map { $ARG->{id} + 0 } grep { defined $ARG->{hashtag_id} and $ARG->{id} == $ARG->{hashtag_id} and $ARG->{directory} == 1 } @{$hashtags};
    my @hashtags_checked = map { $ARG + 0 } $request->parameters()->get_all( 'd4-hashtag_id', );

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

    my $user    = $self->user();
    my $user_id = $user->id();

    for my $hashtag_id (@delete) {

        my $hashtag_directory_row = 'Note::Row'->new( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, );

        if ( defined $hashtag_directory_row->id() ) {

            $hashtag_directory_row->update(
                {

                    ts_directory => undef,
                    user_id      => $user_id,
                },
            );

        }

        my $hashtag_row = 'Note::Row'->new( ring_hashtag => { id => $hashtag_id, }, );

        if ( defined $hashtag_row->id() ) {

            $hashtag_row->update( { directory => 0, }, );

        }

    }

    for my $hashtag_id (@add) {

        my $hashtag_directory_row = 'Note::Row::find_create'->( ring_hashtag_directory => { hashtag_id => $hashtag_id, }, { ts_created => \'NOW()', }, );

        if ( defined $hashtag_directory_row->id() ) {

            $hashtag_directory_row->update(
                {

                    ts_directory => \'NOW()',
                    user_id      => $user_id,
                },
            );

        }

        my $hashtag_row = 'Note::Row'->new( ring_hashtag => { id => $hashtag_id, }, );

        if ( defined $hashtag_row->id() ) {

            $hashtag_row->update( { directory => 1, }, );

        }

    }

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => { page => $page, }, ), );
}

sub search {
    my ( $self, $form_data, $args, ) = @_;

    my ( $search, ) = ( $form_data->{search} =~ m{ \A ( \w+ ) \z }xms, );

    my $form = $self->form();

    # $self->form()->{search} = $form_data->{search};
    $form->{search} = $form_data->{search};

    my $value = $self->value();

    if ( defined $search ) {

        # $self->value()->{search} = $search;
        $value->{search} = $search;
    }

    return;
}

sub filter {
    my ( $self, $form_data, $args, ) = @_;

    my ( $category_id, ) = ( $form_data->{category_id} =~ m{ \A ( \d+ ) \z }xms, );

    my $form = $self->form();

    # $self->form()->{category_id} = $form_data->{category_id};
    $form->{category_id} = $form_data->{category_id};

    my $value = $self->value();

    if ( defined $category_id ) {

        # $self->value()->{category_id} = $category_id;
        $value->{category_id} = $category_id;
    }

    return;
}

1;
