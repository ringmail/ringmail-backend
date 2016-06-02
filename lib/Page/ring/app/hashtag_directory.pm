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

our %DIRECTORY = (
	'Lifestyle' => {
		'pattern' => 'wov',
		'color' => 'grapefruit',
	},
	'Technology' => {
		'pattern' => 'squared_metal',
		'color' => 'denim',
	},
	'Stocks' => {
		'pattern' => 'swirl_pattern',
		'color' => 'grass',
	},
	'News' => {
		'pattern' => 'upfeathers',
		'color' => 'turquoise',
	},
	'Shopping' => {
		'pattern' => 'dimension',
		'color' => 'banana',
	},
	'Boom' => {
		'pattern' => 'upfeathers',
		'color' => 'turquoise',
	},
);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	::log('hashtag directory', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
	if ($user)
	{
		$res->{'result'} = 'ok';
		my $path = $form->{'path'};
		if ($path eq 'root')
		{
			my @cat = ();
			foreach my $c (
				'Lifestyle',
				'Technology',
				'Stocks',
				'News',
				'Shopping',
				'Boom',
			) {
				push @cat, {
					'type' => 'hashtag_category',
					'name' => $c,
					%{$DIRECTORY{$c}},
				};
			}
			$res->{'directory'} = \@cat;
		}
		elsif (exists $DIRECTORY{$path})
		{
			my @cat = (
				{
					'type' => 'hashtag_category_header',
					'name' => $path,
					%{$DIRECTORY{$path}},
				}
			);
			foreach my $i (1..10)
			{
				my $tag = '#tag'. $i;
				push @cat, {
					'type' => 'hashtag',
					'label' => $tag,
					'session_id' => $tag,
				};
			}
			$res->{'directory'} = \@cat;
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;

