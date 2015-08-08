package Page::ring::index;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use Email::Valid;

use Note::XML 'xml';
use Note::Row;
use Note::Param;

use Ring::User;
use Ring::Route;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	return $obj->SUPER::load($param);
}

sub cmd_webgw
{
	my ($obj, $data, $args) = @_;
	::_log('Web Gateway', $data);
	my $target = $data->{'target'};
	my $did = $data->{'caller_did'};
	if (Email::Valid->address($target))
	{
		$did =~ s/\D//g;
		$did =~ s/^1//;
		if (length($did) == 10)
		{
			my $erec = new Note::Row(
				'ring_email' => {
					'email' => $target,
				},
			);
			if ($erec->id())
			{
				my $router = new Ring::Route();
				my $rt = $router->get_route(
					'target' => 'email',
					'target_email' => $target,
				);
				#::_log("Pre Route:", $rt);
				if (defined $rt)
				{
					my $qname = $router->get_random_server();
					$rt->{'hostname'} = $router->get_host_name($qname);
					my $fsroute = $router->get_route_fs($rt);
					#::_log("FS Route:", $fsroute);
					$router->send_request('did_prompt', {
						'queuehost' => $qname,
						'did_number' => '1'. $did, # caller did
						'cid_number' => '1'. $did, # caller did
						'route' => $fsroute,
					});
				}
			}
		}
	}
}

1;

