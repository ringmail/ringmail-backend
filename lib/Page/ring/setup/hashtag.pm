package Page::ring::setup::hashtag;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::HashtagFactory;

extends 'Page::ring::user';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $content = $obj->content();
	my $form = $obj->form();
	my $user = $obj->user();
	my $uid = $user->id();
	my $id = $form->{'id'};
	unless ($id =~ /^\d+$/)
	{
		return $obj->redirect('/u/hashtags');
	}
	my $ht = new Note::Row(
		'ring_hashtag' => {
			'id' => $id,
			'user_id' => $uid,
		},
	);
	unless ($ht->id())
	{
		return $obj->redirect('/u/hashtags');
	}
	$content->{'hashtag'} = $ht->data('hashtag');
	return $obj->SUPER::load($param);
}

1;

