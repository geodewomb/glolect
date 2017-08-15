#!/usr/bin/local/perl6


my $today = Date.today;
my $lookup = slurp("{$today.year}/{$today.month}/{$today.day}/refer.txt");   
my ($y,$w,$f) = $lookup.split('|');

copy "year-$y/week-$w/index.shtml", "index.shtml";
copy "year-$y/week-$w/tribar.html", "tribar.html";
copy "year-$y/week-$w/scrips.html", "scrips.html";
copy "year-$y/week-$w/info.html", "info.html";

copy "{$today.year}/{$today.month}/{$today.day}/index.html", "today.html";   
