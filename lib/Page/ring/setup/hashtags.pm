package Page::ring::setup::hashtags;

use strict;
use warnings;

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use English '-no_match_vars';

use Note::XML 'xml';
use Note::Param;
use Note::Account qw(account_id transaction tx_type_id);

use Ring::User;
use Ring::Model::Hashtag;
use Ring::Model::Category;
use Ring::Model::RingPage;

extends 'Page::ring::user';

around load => sub {
    my ( $next, @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $content = $self->content();
    my $user    = $self->user();
    my $account = Note::Account->new( $user->id() );
    my $uid     = $user->id();
    my $factory = Ring::Model::Hashtag->new();
    my $ht      = $factory->get_user_hashtags( 'user_id' => $uid, );

    $content->{balance} = $account->balance();
    $content->{'hashtag_table'} = $ht;

    my $category = Ring::Model::Category->new( caller => $self, );
    my $categories = $category->list();

    my @categories;

    push @categories, map { [ $ARG->{title} => $ARG->{name}, ]; } @{$categories};

    $content->{category_list}       = \@categories;
    $content->{category_sel}        = 0;
    $content->{category_opts}->{id} = 'category';

    my $ringpage = Ring::Model::RingPage->new();
    my $ringpages = $ringpage->list( user_id => $user->id(), );

    my @ringpages;

    if ( scalar @{$ringpages} ) {
        push @ringpages, map { [ $ARG->{ringpage} => $ARG->{id}, ]; } @{$ringpages};
    }
    else {
        push @ringpages, [ '(No RingPages Created)' => undef, ];
    }

    $content->{ringpage_list} = \@ringpages;
    $content->{ringpage_opts}->{id} = 'ringpage';

    return $self->$next( $param, );
};

sub cmd_hashtag_add {
    my ( $self, $data, $args ) = @_;

    my $user   = $self->user();
    my $uid    = $user->id();
    my $tag    = lc( $data->{'hashtag'} );
    my $target = $data->{'target'};
    if ( $target ne q{} ) {

        $target =~ s/^\s*//xms;    # trim whitespace
        $target =~ s/\s*$//xms;
        if ( not $target =~ m{^http(s)?://}xmsi ) {
            $target = 'http://' . $target;
        }

    }
    my $factory = Ring::Model::Hashtag->new();
    if ( $factory->validate_tag( 'tag' => $tag, ) ) {
        if ( $factory->check_exists( 'tag' => $tag, ) ) {
            ::log('Dup');
        }
        else {
            if ( $factory->validate_target( 'target' => $target, ) or defined $data->{ringpage_id} ) {

                my $src = Note::Account->new( $uid, );
                my $dst = account_id('revenue_ringmail');

                transaction(
                    acct_dst => $dst,
                    acct_src => $src,
                    amount   => '1.99',                           # TODO fix
                    tx_type  => tx_type_id('purchase_hashtag'),
                    user_id  => $uid,
                );

                ::log( $data, );

                my $category = $data->{category};
                my ( $ringpage_id, ) = ( $data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );

                ::log( $ringpage_id, );

                my $res = $factory->create(
                    category    => $category,
                    ringpage_id => $ringpage_id,
                    tag         => $tag,
                    target_url  => $target,
                    user_id     => $uid,
                );
                if ( defined $res ) {

                    ::log( 'New', $res );
                }
            }
            else {
                ::log('Bad Target');
            }
        }
    }

    return;
}

sub cmd_hashtag_delete {
    my ( $self, $data, $args ) = @_;
    my $user    = $self->user();
    my $uid     = $user->id();
    my $tagid   = $args->[0];
    my $factory = Ring::Model::Hashtag->new();
    if ($factory->delete(
            'user_id' => $uid,
            'id'      => $tagid,
        )
        )
    {
        # display confirmation
    }
    else {
        # failed
    }

    return;
}

1;
