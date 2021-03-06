#!/usr/bin/perl -I/home/mfrager/note
use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use strict;
use warnings;

no warnings qw(uninitialized);

use Note::Base;
use Net::XMPP;

my $server = 'staging.ringmail.com';
my $port = 5222;
my $username = 'appletest1gmailcom';
my $password = `cat /home/note/xmpp_pass.txt`;
my $resource = 'RingMail';

chomp($password);

$SIG{HUP} = \&Stop;
$SIG{KILL} = \&Stop;
$SIG{TERM} = \&Stop;
$SIG{INT} = \&Stop;

::log("[$password]");

my $Connection = new Net::XMPP::Client(
	'debuglevel' => 2,
);

$Connection->SetCallBacks(message=>\&InMessage,
                          presence=>\&InPresence,
                          iq=>\&InIQ);

my $status = $Connection->Connect(hostname=>$server,
                                  port=>$port,
                                  tls=>1);

if (!(defined($status)))
{
    print "ERROR:  Jabber server is down or connection was not allowed.\n";
    print "        ($!)\n";
    exit(0);
}

my @result = $Connection->AuthSend(username=>$username,
                                   password=>$password,
                                   resource=>$resource);

if ($result[0] ne "ok")
{
    print "ERROR: Authorization failed: $result[0] - $result[1]\n";
    exit(0);
}

print "Logged in to $server:$port...\n";
#$Connection->RosterGet();
#print "Getting Roster to tell server to send presence info...\n";
#$Connection->PresenceSend();
#print "Sending presence to tell world that we are logged in...\n";
while(defined($Connection->Process())) { }
print "ERROR: The connection was killed...\n";
exit(0);


sub Stop
{
    print "Exiting...\n";
    $Connection->Disconnect();
    exit(0);
}

sub InMessage
{
    my $sid = shift;
    my $message = shift;
    
    my $type = $message->GetType();
    my $fromJID = $message->GetFrom("jid");
    
    my $from = $fromJID->GetUserID();
    my $resource = $fromJID->GetResource();
    my $subject = $message->GetSubject();
    my $body = $message->GetBody();
    print "===\n";
    print "Message ($type)\n";
    print "  From: $from ($resource)\n";
    print "  Subject: $subject\n";
    print "  Body: $body\n";
    print "===\n";
    print $message->GetXML(),"\n";
    print "===\n";
}

sub InIQ
{
    my $sid = shift;
    my $iq = shift;
    
    my $from = $iq->GetFrom();
    my $type = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
    print "===\n";
    print "IQ\n";
    print "  From $from\n";
    print "  Type: $type\n";
    print "  XMLNS: $xmlns";
    print "===\n";
    print $iq->GetXML(),"\n";
    print "===\n";
}

