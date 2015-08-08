package Page::ring::setup::domain_code;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use Regexp::Common 'net';

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::API;

extends 'Page::ring::user';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $val = $obj->value();
	my $user = $obj->user();
	my $uid = $user->id();
	unless ($form->{'id'} =~ /^\d+$/)
	{
		return $obj->redirect('/u/settings/domains');
	}
	my $out = Ring::API->cmd(
		'path' => ['user', 'target', 'verify', 'domain', 'list'],
		'data' => {
			'user_id' => $uid,
			'domain_id' => $form->{'id'},
		},
	);
	if ($out->{'ok'})
	{
		my $list = $out->{'list'};
		unless (scalar(@$list) == 1)
		{
			return $obj->redirect('/u/settings/domains');
		}
		if ($val->{'verify'})
		{
			$content->{'verify_progress'} = 1;
		}
		elsif ($val->{'download'})
		{
			my $resp = $obj->response();
			$resp->content_type('text/html');	
			my $sh = substr($list->[0]->{'verify_code'}, 0, 16);
			$resp->header('Content-Disposition' => "attachment; filename=ringmail_$sh.html");
			my $body = "ringmail-domain-verify=$list->[0]->{'verify_code'}\n";
			return $body;
		}
		elsif ($form->{'verify'}) # ajax request to actually verify
		{
			my $check = Ring::API->cmd(
				'path' => ['user', 'target', 'verify', 'domain', 'check'],
				'data' => {
					'user_id' => $uid,
					'domain_id' => $form->{'id'},
				},
			);
			my $json = encode_json({
				'ok' => $check->{'ok'},
				'error' => $check->{'error'} || '',
			});
			$obj->response()->content_type('text/plain');
			return $json;
		}
		$val->{'domain'} = $list->[0]->{'domain'};
		$val->{'code'} = $list->[0]->{'verify_code'};
		$val->{'code_short'} = substr($list->[0]->{'verify_code'}, 0, 16);
	}
	return $obj->SUPER::load($param);
}

sub cmd_verify_download
{
	my ($obj, $data, $args) = @_;
	$obj->value()->{'download'} = 1;
	$obj->form()->{'id'} = $args->[0];
}

sub cmd_verify
{
	my ($obj, $data, $args) = @_;
	$obj->value()->{'verify'} = 1;
	$obj->form()->{'id'} = $args->[0];
}

1;

