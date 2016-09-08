package Page::ring::setup::admin::directory;

use English '-no_match_vars';
use Moose 'extends';
use Note::Param 'get_param';
use Note::SQL::Table 'sqltable';
use Regexp::Common 'whitespace';
use Ring::Model::Category;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param, ) = get_param( @args, );

    my ( $page, )        = ( ( $self->form()->{page}        // 1 ) =~ m{ \A ( \d+ ) \z }xms, );
    my ( $search, )      = ( ( $self->form()->{search}      // q{} ) =~ m{ \A ( \w+ ) \z }xms, );
    my ( $category_id, ) = ( ( $self->form()->{category_id} // q{} ) =~ m{ \A ( \d+ ) \z }xms, );

    my $where_clause = {

        defined $search ? ( hashtag => [ like => qq{%$search%}, ], ) : (),
        defined $category_id ? ( 'ring_hashtag.category_id' => $category_id ) : (),

    };

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
        order => qq{ring_hashtag.hashtag ASC LIMIT $offset, 10},
    );

    my $count = sqltable('ring_hashtag')->count( $where_clause, );

    my $category_model = 'Ring::Model::Category'->new();
    my $categories     = $category_model->list();

    $self->content()->{category_list} = [ map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories}, ];
    $self->content()->{count}         = $count;
    $self->content()->{hashtags}      = $hashtags;

    return $self->SUPER::load( $param, );
}

sub approve {
    my ( $self, $form_data, $args, ) = @_;

    my $where_clause = {

        defined $search ? ( hashtag => [ like => qq{%$search%}, ], ) : (),
        defined $category_id ? ( 'ring_hashtag.category_id' => $category_id ) : (),

    };

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

    my ( $cmdnum, ) = map {
        do {

            my ( $cmdnum, ) = ( $ARG =~ m{ do-\d+_( \d+ ) }xms, );

            ( defined $cmdnum and $self->form()->{$ARG} eq q{} ) ? ( $cmdnum, ) : ();

        };
    } keys %{ $self->form() };

    my @hashtags_approved = map { $ARG->{id} + 0 } grep { defined $ARG->{hashtag_id} and $ARG->{id} == $ARG->{hashtag_id} and $ARG->{directory} == 1 } @{$hashtags};
    my @hashtags_checked = map { $ARG + 0 } $self->request()->parameters()->get_all( "d$cmdnum-hashtag_id", );

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

    my $user_id = $self->user()->id();

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

    my ( $page, )        = ( ( $self->form()->{page}        // 1 ) =~ m{ \A ( \d+ ) \z }xms, );
    my ( $search, )      = ( ( $self->form()->{search}      // q{} ) =~ m{ \A ( \w+ ) \z }xms, );
    my ( $category_id, ) = ( ( $self->form()->{category_id} // q{} ) =~ m{ \A ( \d+ ) \z }xms, );

    my $query = {

        defined $page        ? ( page        => $page, )        : (),
        defined $search      ? ( search      => $search, )      : (),
        defined $category_id ? ( category_id => $category_id, ) : (),

    };

    return $self->redirect( $self->url( path => join( q{/}, @{ $self->path() }, ), query => $query, ), );
}

sub search {
    my ( $self, $form_data, $args, ) = @_;

    my ( $search, ) = ( lc( $form_data->{search} ) =~ m{ ( [\s\w\#\,\-]+ ) }xms, );

    if ( not defined $search ) {

        $self->form()->{search} = $form_data->{search};
        $self->value()->{error} = 'Invalid input.';

        return;

    }

    $search =~ s{ [_\#\,\-]+ }{ }gxms;
    $search =~ s{$RE{ws}{crop}}{}gxms;
    $search =~ s{ \s+ }{_}gxms;

    ( $search, ) = ( $search =~ m{ \A ( \w{1,139} ) \z }xms, );

    if ( not defined $search ) {

        $self->form()->{search} = $form_data->{search};
        $self->value()->{error} = 'Invalid input.';

        return;

    }
    else {

        $self->form()->{search} = $search;

        return;

    }

    return;
}

sub filter {
    my ( $self, $form_data, $args, ) = @_;

    my ( $category_id, ) = ( $form_data->{category_id} =~ m{ \A ( \d+ ) \z }xms, );

    $self->form()->{category_id} = $form_data->{category_id};

    if ( defined $category_id ) {

        $self->value()->{category_id} = $category_id;
    }

    return;
}

1;
