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
use Ring::Model::Hashtag;

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
	#::log($ht->data());
	unless ($ht->id())
	{
		return $obj->redirect('/u/hashtags');
	}
	$content->{'hashtag'} = $ht->data('hashtag');
	$content->{'target_url'} = $ht->data('target_url');
	$content->{'edit'} = ($form->{'edit'}) ? 1 : 0;
	return $obj->SUPER::load($param);
}

sub cmd_hashtag_edit
{
	my ($obj, $data, $args) = @_;
	my $user = $obj->user();
	my $uid = $user->id();
	my $tagid = $args->[0];
	my $target = $data->{'target'};
	$target =~ s/^\s*//; # trim whitespace
	$target =~ s/\s*$//;
	unless ($target =~ m{^http(s)?://}i)
	{
		$target = 'http://'. $target;
	}
	my $factory = new Ring::Model::Hashtag();
	if ($factory->validate_target(
		'target' => $target,
	)) {
		if ($factory->update(
			'user_id' => $uid,
			'id' => $tagid,
			'target' => $target,
		)) {
			# display confirmation
		}
		else
		{
			# failed
		}
	}
	else
	{
		# invalid target
	}
}

1;

