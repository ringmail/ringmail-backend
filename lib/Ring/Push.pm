package Ring::Push;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use JSON::XS 'decode_json';
use Digest::MD5 'md5_hex';
use Net::APNS::Persistent;
#use Net::APNS::Feedback;

use Note::Param;
use Note::Row;

use Ring::Route;
use Ring::User;

no warnings qw(uninitialized);

sub push_message
{
	my ($obj, $param) = get_param(@_);
	my $to = $param->{'to'};
	my $route = new Ring::Route();
	my $uid = $route->get_target_user_id('target' => $to);
	if (defined $uid)
	{
		my $user = new Ring::User($uid);
		my $rc = new Note::Row(
			'ring_user_apns' => {
				'user_id' => $uid,
			},
		);
		if ($rc->id())
		{
			my $apns = $rc->data('main_token');
			if (defined($apns) && length($apns))
			{
				my $body = $param->{'from'}. ': '. $param->{'body'};
				my $params = {
					'token' => $apns,
					'body' => (length($body) > 160) ? substr($body, 0, 160) : $body,
					'loc-key' => 'CHAT',
					'sound' => 'chat_in_alert.caf',
					'data' => {
						'tag' => substr(md5_hex($param->{'from'}), 0, 10),
					},
				};
				$obj->apns_push($params);
			}
		}
	}
}

sub push_call
{
	my ($obj, $param) = get_param(@_);
	my $to = $param->{'to'};
	my $from = $param->{'from'};
	my $route = new Ring::Route();
	my $uid = $route->get_target_user_id('target' => $to);
	if (defined $uid)
	{
		my $user = new Ring::User($uid);
		my $rc = new Note::Row(
			'ring_user_apns' => {
				'user_id' => $uid,
			},
		);
		if ($rc->id())
		{
			my $apns = $rc->data('voip_token');
			if (defined($apns) && length($apns))
			{
				my $body = $param->{'from'};
				my $params = {
					'voip' => 1,
					'token' => $apns,
					'body' => (length($body) > 160) ? substr($body, 0, 160) : $body,
					'sound' => 'msg.caf',
				};
				$obj->apns_push($params);
			}
		}
	}
}

# params: 
#  pn-tok pn-call-str pn-call-snd body data
sub apns_push
{
	my ($obj, $param) = get_param(@_);
	::log("PUSH:", $param);
	if ($param->{'voip'})
	{
		my $apns = new Net::APNS::Persistent($::app_config->{'push_apns_voip'});
		my $data = $param->{'data'};
		$data ||= {};
		$apns->queue_notification(
			$param->{'token'},
			{
				'aps' => {
					'alert' => {
						'body' => 'Call',
					},
				},
				'from' => $param->{'body'},
			},
		);
		$apns->send_queue();
		$apns->disconnect();
	}
	else
	{
		my $apns = new Net::APNS::Persistent($::app_config->{'push_apns'});
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
}

#my $fb = Net::APNS::Feedback->new({
#	'sandbox' => 1,
#	'cert' => '/home/mfrager/ringmail_apns_dev.pem',
#	'key' => '/home/mfrager/ringmail_apns_dev_key.pem',
#});
#my @feedback = $fb->retrieve_feedback;
#print Dumper(\@feedback);

1;

