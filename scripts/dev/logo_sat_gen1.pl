#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;
use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';

#use Note::Base;
use Graphics::Magick;
use Data::Dumper;

no warnings qw(uninitialized);

my $fp = '/home/note/app/ringmail/data/logo_gen/ringmail-satellite-generator1.png';
my $dp = '/home/note/app/ringmail/static/img/logo_gen/logo_'. time(). '.png';
my $msg = $ARGV[0];

my $p = new Graphics::Magick();
$p->Read($fp);
my @res = $p->QueryFontMetrics(
	'text' => $msg,
	'font' => 'helvetica',
	'geometry' => '+0+0',
	'pointsize' => '175',
);
#print Dumper(\@res);
my $w = $res[4];
my $tw = 220 + int($w) + 20;
my $h = $p->Get('height');

#print "Width: $w\n";
#print "Height $h\n";

$p->Annotate(
	'text' => $msg,
	'geometry' => '+220+180',
	'fill' => '#33362f',
	'font' => 'helvetica',
	'pointsize' => '175',
);
$p->Crop('geometry' => "${tw}x${h}+0+0");
$p->Write($dp);
print "$dp\n";

