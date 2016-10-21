#!/usr/bin/perl -wT 
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use strict;
use warnings;

use Net::DNS::Nameserver;

use Note::Base;

my $ns = new Net::DNS::Nameserver(
	'LocalAddr' => "0.0.0.0",
	'LocalPort' => "5353",
	'ReplyHandler' => sub {
		my ($qname, $qclass, $qtype, $peerhost,$query,$conn) = @_;
		my ($rcode, @ans, @auth, @add);
		print "Received query from $peerhost to ". $conn->{'sockhost'}. "\n";
		$query->print;
		if ($qtype eq "A" && $qname eq "gmail.com.ring.ml")
		{
			my ($ttl, $rdata) = (60, "172.31.8.117");
			my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
			push @ans, $rr;
			$rcode = "NOERROR";
		}
		elsif( $qname eq "foo.example.com" )
		{
			$rcode = "NOERROR";
		}
		else
		{
			$rcode = "NXDOMAIN";
		}

		# mark the answer as authoritive (by setting the 'aa' flag
		return ($rcode, \@ans, \@auth, \@add, { aa => 1 });
	},
	'Verbose' => 1,
);

