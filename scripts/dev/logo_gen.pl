#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;
use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';

#use Note::Base;
use Image::Magick;
use Data::Dumper;

no warnings qw(uninitialized);

my $fp = '/home/note/app/ringmail/data/logo_gen/ringmail-logo-generator1.png';
my $dp = '/home/note/app/ringmail/static/img/logo_gen/logo_'. time(). '.png';
my $msg = $ARGV[0];

my $p = new Image::Magick();
$p->Read($fp);
my @res = $p->QueryFontMetrics(
	'text' => $msg,
	'font' => 'helvetica',
	'geometry' => '+0+0',
	'pointsize' => '540',
);
#print Dumper(\@res);
my $w = $res[4];
my $tw = 1241 + int($w) + 90;
my $h = $p->Get('height');

#print "Width: $w\n";
#print "Height $h\n";

$p->Annotate(
	'text' => $msg,
	'geometry' => '+1241+662',
	'pen' => '#33362f',
	'font' => 'helvetica',
	'pointsize' => '540',
);
$p->Crop('geometry' => "${tw}x${h}+0+0");
$p->Write($dp);
print "$dp\n";

