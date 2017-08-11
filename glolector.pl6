#!usr/local/bin/perl6
use v6;


# step one
process_data('lectdat.txt');


### subroutines ##########################################

sub deduce_year(%day) {

  my @yearlett = <c a b>;
  my $mod = 0;
  $mod = 1 if %day<season>.lc ~~ /advent||christmas/ and %day<date>.month ~~ /11||12/;
  return @yearlett[(%day<date>.year + $mod) % 3];
}

sub gateway($ref) {   ### links to scripture text (not implemented)

  my $link = '<a href=" ">' ~ $ref ~ '</a>';
  return $link;
}

sub html_daily(%d) {   ### constructs index.html for daily entries

  # find either/or options and format
  while %d<scrips> ~~ / '{' .+? '}' / {
    my $eitheror = $/.Str.split('|').join("<br>\n<span>or</span> ");
    $eitheror = $eitheror.split(['{','}']).join;
    $eitheror = '<p class="eitheror">' ~ $eitheror.split(';').join("<br>\n") ~ "</p>";
    %d<scrips> = $/.prematch ~ $eitheror ~ $/.postmatch;
  }

  # divide scripture string and tag with html
  my @scrips = %d<scrips>.split(';');
  for @scrips {
    given $_ {
      when /'[' (.+) ']'/ { $_ = "<h3>" ~ $0.Str ~ "/h3>"; }
      when /'AM'||'PM'/   { $_ = "<h4>" ~ $_ ~ "</h4>"; }
      when /'<p class'/   { next; }
      when /^'(' (.+) ')'$/ { $_ = '<p class="glo">+ ' ~ gateway($0.Str) ~ " +</p>"; } 
      default             { $_ = "<p>" ~ gateway($_) ~ "</p>"; }
    }
  }
  %d<scrips> = @scrips.join("\n");
  
  # make html chunk for a day
  my @day = <_ Monday Tuesday Wednesday Thursday Friday Saturday Sunday>;
  my @month = <_ Jan Feb March April May June July Aug Sept Oct Nov Dec>;

  return qq:to/END/;
  <h1>{@day[%d<date>.day-of-week]}</h1>
  <h2>{%d<date>.day} {@month[%d<date>.month]}</h2>
  <h3>{%d<feast>}</h3>
  {%d<scrips>}
  END
}

sub html_weekly(@w) { ### makes actual html file for a week out of daily chunks

  my @scrips;
  for 1..7 { push @scrips, "<article>\n" ~ @w[$_]<scrips> ~ "</article>"; }
  my $scripstr = @scrips.join("\n");
  return $scripstr;
}
  
sub index_weekly($scrips,%i) { ### make entire index file for a week
  
  return qq:to/END/;
  <!DOCTYPE html>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Glo Lect | Year {%i<year>.uc} | Week {%i<num>}</title>
  
  <section class="next">
  {$fore}
  {$back}
  </section>
  <section class="scrips">
  {$scrips}
  </section>
  </body>
  </html>
  END
}



sub lets_call_it_a_day($line) {   ### splits lectdata line into various info

  my %day;

  $line ~~ /^ (\d\d\d\d) '/' (\d\d?) '/' (\d\d?) /;
  %day<date> = Date.new($0.Int,$1.Int,$2.Int);

  if $line ~~ /'=[' (.+) ']'\t/ { %day<feast> = $0; }
  else { %day<feast> = ''; }

  $line ~~ /\t/;
  %day<scrips> = $/.postmatch;
  
  return %day;
}

sub make_week(@week) {
  
  # create files by date
  for 1..7 -> $d {
    my $date = @week[$d]<date>;
    my $dir = "{$date.year}/{$date.month}/{$date.day}"; 
    mkdir $dir unless $dir.IO.e;
 
    @week[$d]<scrips> = html_daily(@week[$d]);
    spurt "$dir/scrips.html", @week[$d]<scrips>; 
  }

  # create files by year/week

  my $dir = "year-{@week[0]<year>}/week-{@week[0]<num>}";  
  mkdir $dir unless $dir.IO.e;

  my $html = html_weekly(@week);
  spurt "$dir/scrips.html", $html;

  my $index = index_weekly($html,@week[0]);
  spurt "$dir/index.shtml", $index;

  my $info = "{@week[0]<year>}|{@week[0]<num>}|{@week[0]<season>}";
  spurt "$dir/info.txt", $info;
  
}

sub process_data($lectdat) { ### sort of the main program i guess

  my %weekinfo = year => 'x', num => 1, season => 'ordinary';
  my @workweek;
  push @workweek, %weekinfo;

  for $lectdat.IO.lines -> $line {
    given $line {

      when /^'#'/ { next; } # skip comments
      
      when /\t/ { # process days            
        my %day = lets_call_it_a_day($line); 
        %day<season> = @workweek[0]<season>;
        %day<feast> = %day<season> if !%day<feast>;

        # load into working week
        my $y = %day<date>.day-of-week;
        @workweek[$y] = %day;

        # send completed week off to the printers
        unless $y == 7 { next; }  
        unless $line ~~ /'=['.+']'\t/ { say "Sunday, but not Feast day. Verify data: $line"; }
        @workweek[0]<year> = deduce_year(@workweek[7]);
        make_week(@workweek);

        # reset working week
        @workweek[0]<num>++;
        @workweek.pop until @workweek.elems == 1; 
      }

      when /^<:Lu>+/ { 
        # change seasons
        @workweek[0]<season> = $line.lc;
       
        # setup and reset year on year change 
        if $line.lc ~~ /advent/ {
          redirect_final_week(@workweek[0]<year>,@workweek[0]<num>);
          @workweek[0]<num> = 1;
          say "built year {@workweek[0]<year>}";
        }
      }
      default { say "Don't know what to do with: $line"; }
    }
  }  
}

sub redirect_final_week($y,$w) { ### set up htaccess redirects to navigate trickily between years

  return if $y eq 'x';
  unless ".htaccess".IO.e { say "Did not update .htaccess, no file."; return; }
  my $z = swap($y);
  my $path = slurp('etc/path.txt') or $path = '/';

  my $hta = slurp(".htaccess"); 
  if $hta ~~ / \s'/year-'$y'/week-'\d\d\s / { spurt ".htaccess", $hta.subst($/, " /year-{$y}/week-{$w} ", :g); }
  else { spurt ".htaccess", "Redirect 302 /year-{$y}/week-{$w} {$path}year-{$z}/week-1\n", :append; }

  $hta = slurp(".htaccess"); 
  if $hta ~~/ '/year-'$y'/week-'\d\d\n / { spurt ".htaccess", $hta.subst($/, "/year-{$y}/week-{$w - 1}\n", :g); }
  else { spurt ".htaccess", "Redirect 302 /year-{$z}/week-0 {$path}year-{$y}/week-{$w -1}\n", :append; }
  
  
}

sub swap($y) { ### figure out what the next year letter is
  my %swap = a => 'b', b => 'c', c => 'a';
  return %swap{$y};
}
