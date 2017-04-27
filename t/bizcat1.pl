#!/usr/bin/perl
use strict;
use warnings;

use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Note::Base;
use Ring::BusinessCategory;

my $bc = new Ring::BusinessCategory();

::log($bc->get_path('category_id' => 255));

::log($bc->get_category_id('path' => $bc->get_path('category_id' => 255)));

