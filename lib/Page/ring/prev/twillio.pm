package Page::ring::twillio;
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
use Ring::API;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $body = $form->{'Body'};
	$body =~ s/^\s+//;
	$body =~ s/\s+$//;
	my $res;
	my $msg = '';
	if ($body =~ /^help$/)
	{
		$msg = 'RingMail Gateway Messages: more help at 8882027520 or ringmail.com. 1 msg / user request. Reply STOP to cancel. Msg&data rates may apply.';
	}
	elsif ($body =~ /^stop$/)
	{
		$msg = 'You are unsubscribed from RingMail Gateway Messages. No more messages will be sent. Reply HELP for help or 8882027520. Msg&data rates may apply'
	}
	else
	{
		my $did = $form->{'From'};
		$did =~ s/\D//g;
		$did =~ s/^1//;
		#::_log("DID: $did");
		if (length($did) == 10)
		{
			my $router = new Ring::Route();
			my $qname = $router->get_random_server();
			my $clres = Ring::API->cmd(
				'path' => ['route', 'call'],
				'data' => {
					'target' => $body,
					'source' => 'sms_gateway',
					'hostname' => $router->get_host_name($qname),
				},
			);
			if ($clres->{'ok'})
			{
				my %extra = ();
				if ($clres->{'app'})
				{
					$extra{'app'} = $clres->{'app'};
				}
				$router->send_request('did_prompt', {
					'queuehost' => $qname,
					'did_number' => '1'. $did, # caller did
					'cid_number' => '1'. $did, # caller did
					'route' => $clres->{'route'},
					%extra,
				});
			}
		}
	}
	if ($msg)
	{
		$res = xml(
			'Response', [{},
				'Sms', [{},
					0, $msg,
				],
			],
		);
	}
	return $res;
}

1;

