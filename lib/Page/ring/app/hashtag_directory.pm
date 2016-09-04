package Page::ring::app::hashtag_directory;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64';

use Note::XML 'xml';
use Note::Row;
use Note::SQL::Table 'sqltable';
use Note::Param;

use Ring::User;

extends 'Note::Page';

no warnings 'uninitialized';

#our %DIRECTORY = (
#	'Lifestyle' => {
#		'pattern' => 'wov',
#		'color' => 'grapefruit',
#	},
#	'Technology' => {
#		'pattern' => 'squared_metal',
#		'color' => 'denim',
#	},
#	'Stocks' => {
#		'pattern' => 'swirl_pattern',
#		'color' => 'grass',
#	},
#	'News' => {
#		'pattern' => 'upfeathers',
#		'color' => 'turquoise',
#	},
#	'Shopping' => {
#		'pattern' => 'dimension',
#		'color' => 'banana',
#	},
#	'Boom' => {
#		'pattern' => 'upfeathers',
#		'color' => 'turquoise',
#	},
#);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log('hashtag directory', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
	if ($user)
	{
		my $cid = $form->{'category_id'};
		if ($cid =~ /^\d+$/)
		{
			if ($cid == 0)
			{
				my $dq = sqltable('ring_category')->get(
					'select' => [
						'c.id',
						'c.category',
					],
					'table' => 'ring_category c',
					'where' => 'exists (select * from ring_hashtag h where h.category_id=c.id and h.directory=1)',
					'order' => 'category asc',
				);
				my @cat = ();
				foreach my $c (@$dq)
				{
					next if ($c->{'category'} =~ /\(none\)/i);
					push @cat, {
						'type' => 'hashtag_category',
						'name' => $c->{'category'},
						'id' => $c->{'id'},
						'pattern' => 'squared_metal',
						'color' => 'denim',
					};
				}
				#$res->{'directory'} = \@cat;
				my @group = ([]);
				my $max = 2;
				foreach my $i (@cat)
				{
					if (scalar(@{$group[-1]}) == $max)
					{
						push @group, [];
					}
					push @{$group[-1]}, $i;
				}
				foreach my $i (0..$#group)
				{
					$group[$i] = {
						'type' => 'hashtag_category_group',
						'group' => $group[$i],
					};
				}
				$res->{'directory'} = \@group;
				$res->{'result'} = 'ok';
				$obj->{'response'}->header('Cache-Control', 'max-age='. 3600);
			}
			else
			{
				my $catrc = new Note::Row('ring_category' => {'id' => $cid});
				if ($catrc->id())
				{
					my @cat = (
						{
							'type' => 'hashtag_category_header',
							'name' => $catrc->data('category'),
							'id' => $cid,
							'pattern' => 'squared_metal',
							'color' => 'denim',
						}
					);
					my $tq = sqltable('ring_hashtag')->get(
						'select' => [
							'hashtag',
							'target_url',
							'ringpage_id',
						],
						'where' => {
							'category_id' => $cid,
							'directory' => 1,
						},
						'order' => 'hashtag',
					);
					my %seen = ();
					foreach my $i (@$tq)
					{
						if ($i->{'target_url'})
						{
							next if ($seen{$i->{'target_url'}}++);
						}
						if ($i->{'ringpage_id'})
						{
							next if ($seen{$i->{'ringpage_id'}}++);
						}
						my $tag = '#'. $i->{'hashtag'};
						push @cat, {
							'type' => 'hashtag',
							'label' => $tag,
							'session_tag' => $tag,
						};
					}
					$res->{'directory'} = \@cat;
					$res->{'result'} = 'ok';
				}
			}
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;

