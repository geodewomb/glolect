#!/usr/bin/local/perl6


my $today = Date.today;
my $lookup = "{$today.year}/{$today.month}/{$today.day}"; 

if "$lookup/refer.txt".IO.e and "$lookup/index.html".IO.e {

  my ($y,$w,$f) = slurp("$lookup/refer.txt").split('|');

  copy "year-$y/week-$w/index.shtml", "index.shtml";
  copy "year-$y/week-$w/tribar.html", "tribar.html";
  copy "year-$y/week-$w/scrips.html", "scrips.html";
  copy "year-$y/week-$w/info.html", "info.html";

  copy "$lookup/index.html", "today.html";   
}
