package Page::ring::app::business_cat_directory;
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


sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();

	my $parentIdIn = $form->{'parent'};

	::log('business category directory', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'Unauthorized'};
	if ($user)
	{
		my $pid = $form->{'parent'};
		if ($pid =~ /^\d+$/)
		{
			if ($pid == 0)
			{
				my $dq = sqltable('business_category')->get(
					'select' => [
						'c1.id',
						'c1.business_category_name',
						'c1.parent',
						'c1.factual_category_id',
					],
					'table' => 'business_category c1',
					'where' => 'c1.parent IS NULL and c1.factual_category_id IS NULL',
					'order' => 'business_category_name asc',
				);

				my @cat = ();
				foreach my $c (@$dq)
				{
					next if ($c->{'business_category_name'} =~ /\(none\)/i);
					my $catimg = 'hashtagdir.jpg';
					push @cat, {
						'type' => 'hashtag_category',
						'name' => $c->{'business_category_name'},
						'id' => $c->{'id'},
						'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
					};
				}
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
				my $dq = sqltable('business_category')->get(
					'select' => [
						'c1.id',
						'c1.business_category_name',
						'c1.parent',
						'c1.factual_category_id',

					],
					'table' => 'business_category c1, business_category c2',
					'join' => 'c2.id=c1.parent',
					'where' => "c1.parent=$pid",
					'order' => 'business_category_name asc',
				);
				my @cat = ();

				if (@$dq) {

					foreach my $c (@$dq)
					{
						my $catimg = 'hashtagdir.jpg';
						push @cat, {
							'type' => 'hashtag_category',
							'name' => $c->{'business_category_name'},
							'id' => $c->{'id'},
							'image_url' => $obj->url('path' => '/img/hashtag_categories/'. $catimg),
						};
					}
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
					my $catrc = new Note::Row('business_category' => {'id' => $pid});
					if ($catrc->id())
					{
						my @cat = (
							{
								'type' => 'hashtag_category_header',
								'name' => $catrc->data('business_category_name'),
								'id' => $pid,
							}
						);
						my $tq = sqltable('business_place_category')->get(
							'select' => [
								'bhp.hashtag',
								'bpc.category_id',
								'bpc.place_id',
							],
							'table' => 'business_place_category bpc, business_hashtag_place bhp',
							'join' => 'bpc.place_id=bhp.place_id',
							'where' => {
								'bpc.category_id' => $pid,
							},
							'order' => 'bhp.hashtag',
						);
						my %seen = ();
						foreach my $i (@$tq)
						{
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
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;
