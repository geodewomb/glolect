#!/usr/local/bin/perl6


my $today = Date.today;
my $lookup = "{$today.year}/{$today.month}/{$today.day}"; 
my $root = '/home/geneva/public_html/glolect';

if "$root/$lookup/refer.txt".IO.e and "$root/$lookup/index.html".IO.e {

  my ($y,$w,$f) = slurp("$root/$lookup/refer.txt").split('|');

  copy "$root/year-$y/week-$w/index.shtml", "$root/index.shtml";
  copy "$root/year-$y/week-$w/tribar.html", "$root/tribar.html";
  copy "$root/year-$y/week-$w/scrips.html", "$root/scrips.html";
  copy "$root/year-$y/week-$w/info.html", "$root/info.html";

  copy "$root/$lookup/index.html", "$root/today.html";   
}
