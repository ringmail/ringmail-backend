package Page::ring::lookup;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use URI::Escape;
use POSIX 'strftime';
use MIME::Base64 'encode_base64', 'decode_base64';

use Note::XML 'xml';
use Note::Param;

use Ring::Route;
use Ring::Conversation;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::log($form);
	my $res = 'noentry';
	my $route = new Ring::Route();
	my $from = decode_base64($form->{'from'});
	my $to = decode_base64($form->{'to'});
	#::log($from, $to);
	$from =~ s/^sip\://;
	$from =~ s/\@.*//g;
	my $fru = $route->get_phone_user(
		'phone_login' => $from,
	);
	#::log($fru);
#	if (defined $fru)
#	{
#		$from = $fru->{'login'};
#		$from =~ s/\@/\\/;
#		$from = uri_escape($from); # TODO: expand?
#	}
	$to =~ s/^sip\://;
	$to =~ s/\@.*//g;
	$to =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	::log("From: $from To: $to");
	my $target = {};
	if (
		($to =~ /(\\|%)/) || ($to =~ /^\+?\d+$/) || # email or phone number
		($to =~ /^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/) # looks like domain
	) {
		$to =~ s/(\\|%)/@/;
		my $type = $route->get_target_type(
			'target' => $to,
		);
		#::log("Type: ". $type);
		my $dest = $route->get_route(
			'type' => $type,
			$type => $to,
		);
		#::log("Dest ", $dest);
		if (defined $dest)
		{
			my $trow = $route->get_target(
				'type' => $type,
				$type => $to,
			);
			#::log("Target ", $trow);
			if ($type eq 'email' || $type eq 'did')
			{
				# TODO: Conversation codes for different entities
				if (defined($trow) && defined($trow->id()))
				{
					my $cres = $route->setup_conversation(
						'media' => 'call',
						'from_user_id' => $fru->{'user_id'},
						#'from_conversation_uuid' => $uuid,
						'to_user_target' => $trow,
						'to_original' => $to,
					);
					my ($cok, $newto, $newfrom, $touuid, $tocontact) = @$cres;
					#::log("Conv: ok:$cok to:$newto from:$newfrom to_uuid:$touuid to_contact:$tocontact");
					if ($cok eq 'ok')
					{
						my $tologin = $trow->row('user_id', 'ring_user')->data('login');
						::log("Lookup From: $fru->{'login'}|$newfrom -> To: $tologin|$to");
						$newfrom =~ s/\@/\\/;
						$newfrom = uri_escape($newfrom);
						if ($dest->{'route'} eq 'phone')
						{
							$res = "type=phone;from=$newfrom;to=$dest->{'phone'};uuid=$touuid;contact=$tocontact";
						}
					}
				}
			}
			elsif ($type eq 'domain')
			{
				my $newfrom = $fru->{'login'};
				if ($dest->{'type'} eq 'phone')
				{
					$res = "type=phone;from=$newfrom;to=$dest->{'route'}";
				}
				elsif($dest->{'type'} eq 'did')
				{
					$res = "type=did;from=$newfrom;to=$dest->{'route'}";
				}
				elsif ($dest->{'type'} eq 'sip')
				{
					my $sip = encode_base64($dest->{'route'});
					$res = "type=sip;from=$newfrom;to=$sip";
				}
			}
			elsif ($type eq 'hashtag')
			{
				# TODO: code this
			}
		}
		::log("Lookup Result: $res");
		#::log("From: $from To: $to", "Type: $type", "Dest: $res");
		#::log("From: $from To: $dest->{'phone'}");
	}
#	elsif ($to =~ /^#([a-z0-9_]+)/i)
#	{
#		my $tag = lc($1);
#		my $trow = new Note::Row(
#			'ring_hashtag' => {
#				'hashtag' => $tag,
#			},
#			'select' => ['target_url'],
#		);
#		my $url;
#		if ($trow->id())
#		{
#			$url = $trow->data('target_url');
#		}
#		else
#		{
#			$url = 'http://'. $::app_config->{'www_domain'};
#		}
#		$res = "type=url;url=". encode_base64($url);
#	}
	return $res;
}

1;

