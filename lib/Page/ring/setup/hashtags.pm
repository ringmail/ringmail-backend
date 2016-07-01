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
use Note::Row;

use Ring::User;
use Ring::Model::Hashtag;
use Ring::Model::Category;
use Ring::Model::RingPage;

extends 'Page::ring::user';

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $content       = $self->content();
    my $user          = $self->user();
    my $account       = Note::Account->new( $user->id() );
    my $uid           = $user->id();
    my $hashtag_model = Ring::Model::Hashtag->new();
    my $ht            = $hashtag_model->get_user_hashtags( 'user_id' => $uid, );

    $content->{balance} = $account->balance();
    $content->{'hashtag_table'} = $ht;

    my $category_model = Ring::Model::Category->new();
    my $categories     = $category_model->list();

    my @categories;

    push @categories, map { [ $ARG->{category} => $ARG->{id}, ]; } @{$categories};

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

    return $self->SUPER::load( $param, );
}

sub cmd_hashtag_add {
    my ( $self, $form_data, $args, ) = @_;

    my $user             = $self->user();
    my ( $ringpage_id, ) = ( $form_data->{ringpage_id} =~ m{ \A ( \d+ ) \z }xms );
    my $tag              = lc $form_data->{hashtag};
    my $target           = $form_data->{target};

    if ( length $target > 0 ) {

        $target =~ s{ \A \s* }{}xms;    # trim whitespace
        $target =~ s{ \s* \z }{}xms;
        if ( not $target =~ m{ \A http(s)?:// }xmsi ) {
            $target = "http://$target";
        }

    }

    my $hashtag_model = Ring::Model::Hashtag->new();

    if ( $hashtag_model->validate_tag( tag => $tag, ) ) {
        if ( $hashtag_model->check_exists( tag => $tag, ) ) {
            ::log('Dup');
        }
        else {

            my $hashtag = $hashtag_model->create(
                category_id => $form_data->{category_id},
                ringpage_id => $ringpage_id,
                tag         => $tag,
                target_url  => $target,
                user_id     => $user->id(),
            );
            if ( defined $hashtag ) {

                my $hashtag_id = $hashtag->id();

                ::log( "New Hashtag: #$tag", );

                my $cart = Note::Row::create(
                    ring_cart => {
                        hashtag_id => $hashtag_id,
                        user_id    => $user->id(),
                    },
                );

            }
        }
    }

    return;
}

1;
