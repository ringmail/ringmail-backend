package Page::ring::app::lookup_hashtag;
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
	::log('hashtag lookup', {%$form, 'password' => ''});
	my $user = Ring::User::login(
		'login' => $form->{'login'},
		'password' => $form->{'password'},
	);
	my $res = {'result' => 'error'};
	if ($user)
	{
		my $to = $form->{'hashtag'};
		if ($to =~ /^#([a-z0-9_]+)/i)
		{
			my $tag = lc($1);
			my $trow = new Note::Row(
				'ring_hashtag' => {
					'hashtag' => $tag,
				},
				'select' => ['target_url', 'ringpage_id'],
			);
			my $url;
			if ($trow->id())
			{
				if ($trow->data('ringpage_id'))
				{
					$url = $obj->url(
						'path' => '/ringpage',
						'query' => {
							'ringpage_id' => $trow->data('ringpage_id'),
						},
					);
				}
				else
				{
					$url = $trow->data('target_url');
				}
			}
			else
			{
				# default
				$url = 'http://'. $::app_config->{'www_domain'};
			}
			$res = {
				'result' => 'ok',
				'target' => $url,
			};
		}
	}
	$obj->{'response'}->content_type('application/json');
	::log($res);
	return encode_json($res);
}

1;

