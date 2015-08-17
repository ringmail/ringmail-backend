package Ring::Push;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use Net::APNS::Persistent;
use Net::APNS::Feedback;

use Note::Param;
use Note::Row;

no warnings qw(uninitialized);

# params: 
#  pn-tok pn-call-str pn-call-snd body data
sub apns_push
{
	my ($obj, $param) = get_param(@_);
	my %cfg = ();
	if ($param->{'production'})
	{
		%cfg = (
			'cert' => '/home/mfrager/ringmail_apns_prod.pem',
			'key' => '/home/mfrager/ringmail_apns_prod_key.pem',
		);
	}
	else
	{
		%cfg = (
			'sandbox' => 1,
			'cert' => '/home/mfrager/ringmail_apns_dev.pem',
			'key' => '/home/mfrager/ringmail_apns_dev_key.pem',
		);
	}
	my $apns = new Net::APNS::Persistent({
		%cfg,
	});
	my $data = $param->{'data'};
	$data ||= {};
	$apns->queue_notification(
		$param->{'token'},
		{
			'aps' => {
				'alert' => {
					'body' => $param->{'body'},
					'action-loc-key' => $param->{'loc-key'},
				},
				'sound' => $param->{'sound'},
			},
			%$data,
		},
	);
	$apns->send_queue();
	$apns->disconnect();
}

#my $fb = Net::APNS::Feedback->new({
#	'sandbox' => 1,
#	'cert' => '/home/mfrager/ringmail_apns_dev.pem',
#	'key' => '/home/mfrager/ringmail_apns_dev_key.pem',
#});
#my @feedback = $fb->retrieve_feedback;
#print Dumper(\@feedback);

1;

