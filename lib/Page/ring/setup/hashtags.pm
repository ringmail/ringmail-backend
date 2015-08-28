package Page::ring::setup::hashtags;
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
	#my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $user = $obj->user();
	my $uid = $user->id();
	my $factory = new Ring::HashtagFactory();
	my $ht = $factory->get_user_hashtags(
		'user_id' => $uid,
	);
	::log($ht);
	$content->{'hashtag_table'} = $ht;
	return $obj->SUPER::load($param);
}

sub cmd_hashtag_add
{
	my ($obj, $data, $args) = @_;
	my $user = $obj->user();
	my $uid = $user->id();
	my $tag = lc($data->{'hashtag'});
	my $factory = new Ring::HashtagFactory();
	if ($factory->validate(
		'tag' => $tag,
	)) {
		if ($factory->check_exists(
			'tag' => $tag,
		)) {
			::log("Dup");
		}
		else
		{
			my $res = $factory->create(
				'tag' => $tag,
				'user_id' => $uid,
				'target_url' => $data->{'target'},
			);
			if (defined $res)
			{
				#::log("New", $res);
			}
		}
	}
}

1;

