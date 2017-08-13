#!usr/local/bin/perl6
use v6;


my $root = '/';
$root = slurp('etc/path.txt').chomp if 'etc/path.txt'.IO.e;

process_data('lectdat.txt');

set_homepage();


### subroutines ##########################################

sub deduce_year(%day) {

  my @yearlett = <c a b>;
  my $mod = 0;
  $mod = 1 if %day<season>.lc ~~ /advent||christmas/ and %day<date>.month ~~ /11||12/;
  return @yearlett[(%day<date>.year + $mod) % 3];
}

sub gateway {   ### links to scripture text (not implemented)

  my $ref = shift @_;
  my $query = $ref.subst('&', ',', :global);

  my $gateway = "http://www.biblegateway.com/bible?passage=$query";

 $ref = $ref.subst('&', ' & ');

  my $link = '<a href="' ~ $gateway ~ '">' ~ $ref ~ '</a>';
  return $link;
}

sub html_daily(%d) {   ### constructs index.html for daily entries

  # find either/or options and format
  while %d<scrips> ~~ / '{' (.+?) '}' / {
    my @eitheror = "$0".split('|');
    for 0..1 -> $e {
      my @scrips = @eitheror[$e].split(';');
      $_ = gateway($_) for @scrips;
      @eitheror[$e] = @scrips.join("<br>\n");
    }
    my $eitheror = '<p class="eitheror">' ~ @eitheror.join("<br>or ") ~ "</p>";

    %d<scrips> = $/.prematch ~ $eitheror ~ $/.postmatch;
  }

  # divide scripture string and tag with html
  my @scrips = %d<scrips>.split(';');
  for @scrips {
    given $_ {
      when /'[' (.+) ']'/ { $_ = "<h3>" ~ $0.Str ~ "</h3>"; }
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




sub lets_call_it_a_day($line) {   ### splits lectdata line into various info

  my %day;

  $line ~~ /^ (\d\d\d\d) '/' (\d\d?) '/' (\d\d?) /;
  %day<date> = Date.new($0.Int,$1.Int,$2.Int);

  if $line ~~ /'=[' (.+) ']'\t/ { %day<feast> = "$0"; }

  $line ~~ /\t/;
  %day<scrips> = $/.postmatch;
  
  return %day;
}

sub make_svg($season,$link,$flip) {

  my @out = "0 0 22.5 40 45 0", "0 40 22.5 0 45 40";
  my @in = "7.5 3 22.5 17.5 37.5 3", "7.5 37 22.5 22.5 37.5 37";

  return qq:to/END/
  <svg class="{$season}" viewBox="0 0 45 40">
  <a href="{$link}"><g>
  <polygon id="out" points="{@out[$flip]}" fill="#ffffff00" />
  <polygon id="in" points="{@in[$flip]}" fill="#ffffff00" />
  </g></a>
  </svg>
  END
}

sub make_tribars(@data) {

  my @pre;
  my @post = @data;
  push @pre, %( feast => 'generic' ) for ^15;
  push @post, %( feast => 'generic' ) for ^50;
  
  for @data -> $w {
    my @tribar;
    my $flip = 0;

    for @pre {
      my $link = '';
      if $_<year> and $_<num> { $link = "$root/year-{$_<year>}/week-{$_<num>}"; }
      push @tribar, make_svg($_<feast>,$link,$flip);
      $flip = 1 - $flip;
    }
    my $feast = $w<feast> ~ " now";
    push @tribar, make_svg($feast,'',$flip);
    $flip = 1 - $flip;
    for 1..50 {
      my %w = @post[$_];
      my $link = '';
      if %w<year> and %w<num> { $link = "$root/year-{%w<year>}/week-{%w<num>}"; }
      push @tribar, make_svg(%w<feast>,$link,$flip);
      $flip = 1 - $flip;
    }
    
    spurt "year-{$w<year>}/week-{$w<num>}/tribar.html", @tribar.join("\n");

    shift @pre;
    push @pre, shift @post;
  }
  
}
      

sub make_week(@week) {
  
  # create files by date
  for 1..7 -> $d {
    my $date = @week[$d]<date>;
    my $dir = "{$date.year}/{$date.month}/{$date.day}"; 
    mkdir $dir unless $dir.IO.e;
 
    @week[$d]<scrips> = html_daily(@week[$d]);
    spurt "$dir/scrips.html", @week[$d]<scrips>;
    spurt "$dir/refer.txt", "{@week[0]<year>}|{@week[0]<num>}|{@week[0]<feast>}"; 
  }

  # create files by year/week

  my $dir = "year-{@week[0]<year>}/week-{@week[0]<num>}";  
  mkdir $dir unless $dir.IO.e;

  my $info = weekly_info(@week);
  spurt "$dir/info.html", $info;

  my $scrips = weekly_scrips (@week);
  spurt "$dir/scrips.html", $scrips;

  my $index = weekly_index($scrips,@week[0]);
  spurt "$dir/index.shtml", $index;

  

}

sub process_data($lectdat) { ### sort of the main program i guess

  my @workweek;
  @workweek[0] = %( year => 'x', num => 0, season => '', count => 0 );
  my @tribar_data;

  for $lectdat.IO.lines -> $line {
    given $line {

      when /^'#'/ { next; } # skip commented lines
      
      when /\t/ { # process days            
        my %day = lets_call_it_a_day($line);

        # figure out seasons and feast 
        %day<season> = @workweek[0]<season>;
        given %day<feast> { 
          when !%day<feast> { %day<feast> = %day<season>; }
          when /'NATIV'||'NAME'||'PROP'/ { }
          when /EASTER\sDAY/ { %day<feast> = "holyweek"; proceed; }
          default { @workweek[0]<feast> = %day<feast>.comb(/<:L>+/).join('').lc }
        }

        # load into working week
        my $y = %day<date>.day-of-week;
        @workweek[$y] = %day;

        # once the week has 7 days wrap it up add final info
        next unless $y == 7;
        unless $line ~~ /'=['.+']'\t/ { say "Sunday, but not Feast day. Verify data: $line"; }

        @workweek[0]<year> = deduce_year(@workweek[7]);
        @workweek[0]<feast> = @workweek[0]<season> unless @workweek[0]<feast>;

        # send completed week off to the printers
        make_week(@workweek);
        
        # add to tribar info
        my %info = @workweek[0];
        push @tribar_data, %info;

        # reset working week
        @workweek[0]<num>++;
        @workweek[0]<count>++;
        @workweek[0]<feast> = '';
        @workweek.pop until @workweek.elems == 1; 
      }

      when /^<:Lu>+/ { 
        # change seasons
        @workweek[0]<season> = $line.lc;
        @workweek[0]<count> = 1;
       
        # setup and reset year on year change 
        if $line.lc ~~ /advent/ {
          redirect_final_week(@workweek[0]<year>,@workweek[0]<num>);
          @workweek[0]<num> = 1;
          say "built year {@workweek[0]<year>}" unless @workweek[0]<year> eq 'x';
        }
      }
      default { say "Don't know what to do with: $line"; }
    }
  }
  make_tribars(@tribar_data); 
}

sub redirect_final_week($y,$w) { ### set up htaccess redirects to navigate trickily between years

  return if $y eq 'x';
  unless ".htaccess".IO.e { say "Did not update .htaccess, no file."; return; }
  my $z = swap($y);

  my $hta = slurp(".htaccess"); 
  if $hta ~~ / \s'/year-'$y'/week-'\d\d\s / { spurt ".htaccess", $hta.subst($/, " /year-$y/week-$w ", :g); }
  else { spurt ".htaccess", "Redirect 302 $root/year-$y/week-$w $root/year-$z/week-1\n", :append; }

  $hta = slurp(".htaccess"); 
  if $hta ~~/ '/year-'$y'/week-'\d\d\n / { spurt ".htaccess", $hta.subst($/, "/year-$y/week-{$w - 1}\n", :g); }
  else { spurt ".htaccess", "Redirect 302 $root/year-$z/week-0 $root/year-$y/week-{$w -1}\n", :append; }
  
}

sub set_homepage {
  
  my $today = Date.today;
  my $lookup = slurp("{$today.year}/{$today.month}/{$today.day}/refer.txt");   
  my ($y,$w,$f) = $lookup.split('|');
  copy "year-$y/week-$w/index.shtml", "index.shtml";
  copy "year-$y/week-$w/tribar.html", "tribar.html";
  copy "year-$y/week-$w/scrips.html", "scrips.html";
  copy "year-$y/week-$w/info.html", "info.html";

  my $svg = make_svg($f,$root,0);
  my $scrips = slurp("{$today.year}/{$today.month}/{$today.day}/scrips.html");   
  
  my $html = qq:to/END/;
  $svg
  <h1>Today's Scriptures:</h1>
  $scrips
  END

  spurt 'today.html', $html;
}

sub swap($y) { ### figure out what the next year letter is
  my %swap = a => 'b', b => 'c', c => 'a';
  return %swap{$y};
}


sub weekly_scrips(@w) { ### makes actual html file for a week out of daily chunks

  my @scrips;
  for 1..7 { push @scrips, "<article>\n" ~ @w[$_]<scrips> ~ "</article>"; }
  my $scripstr = @scrips.join("\n");
  return $scripstr;
}
  
sub weekly_index($scrips,%i) { ### make entire index file for a week
  

  return qq:to/END/;
  <!DOCTYPE html>
  <title>Glo Lect | Year {%i<year>.uc} | Week {%i<num>}</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" type="text/css" href="{$root}/etc/styles.css"> 
  <body class="{%i<season>}">
  <svg id="swipe-l" viewBox="0 0 40 90" preserveAspectRatio="none"><polygon points="0 0 40 0 0 90" fill="#ffffff00" /></svg>
  <svg id="swipe-r" viewBox="0 0 540 90" preserveAspectRatio="none"><polygon points="0 0 500 0 540 90 0 90" fill="#ffffff00" /></svg>
  <nav>
  <a href="{$root}"><h1>Glo Lec<span class="bigger">+</span></h1></a>
  <h2>daily scriptures from the Revised Common Lectionary<br>
  + complete bible reading plan</h2>
  <ul>
  <li><a href="{$root}/browse">BROWSE</a></li>
  <li><a href="{$root}/faq">FAQ</a></li>
  </ul>
  </nav>
  <header>
  <section class="tribar">
  <!--#include virtual="tribar.html" -->
  </section>
  </header>
  <section class="today">
  <!--#include virtual="{$root}/today.html" -->
  </section>
  <main class="{%i<season>}">
  <section class="info">
  <a href="{$root}/year-{%i<year>}/week-{%i<num> - 1}">
  <svg class="{%i<season>} left" viewBox="0 0 45 80" height="80" width="45"><g>
  <polygon id="out" points="0,40 22.5,0 27.5,0 5,40 27.5,80 22.5,80" fill="#a02c5a"></polygon>
  </g></svg>
  </a>
  <!--#include virtual="info.html" -->
  <a href="{$root}/year-{%i<year>}/week-{%i<num> + 1}">
  <svg class="{%i<season>} right" viewBox="0 0 45 80" height="80" width="45"><g>
  <polygon id="out" points="40,40 17.5,0 22.5,0 45,40 22.5,80 17.5,80" fill="#a02c5a"></polygon>
  </g></svg>
  </a>
  </section>
  <section class="scrips">
  <!--#include virtual="scrips.html" -->
  </section>
  </main>
  </body>
  </html>
  END
}

sub weekly_info(@week) {

  my @numth = <th st nd rd th th th th th th>;
  my $num = @week[0]<count>;
  my $th = $num.substr(*-1,1);

  my $title;
  given @week[0]<feast> {
    when /holyweek/ { $title = "Holy Week and Easter Sunday"; }
    when /baptism/ { $title = "Week of the Baptism of the Lord"; }
    when /epiphanyday/ { $title = "Week of Epiphany Day"; }
    when /allsaints/ { $title = "Week of All Saints Day"; }
    when /christtheking/ { $title = "Week of Christ the King Sunday"; }
    when /ordinary/ { $title = "{$num}{@numth[$th]} Sunday after Pentecost"; }
    when /epiphany||easter/ { $title = "{$num}{@numth[$th]} Sunday after {$_.wordcase}"; }
    when /ascension||thanksgiving/ { $title = "Week of {$_.wordcase} Day"; }
    when /trinity||transfig||pentecost/ { $title = "Week of {$_.wordcase} Sunday"; } 
    default { $title = "{$num}{@numth[$th]} Week of {$_.wordcase}"; }
  }
  my @month = <_ January February March April May June July August September October November December>;

  my $datestr = "{@week[1]<date>.day} {@month[@week[1]<date>.month]}";
  if @week[1]<date>.year != @week[7]<date>.year { $datestr ~= " {@week[1]<date>.year}"; }
  $datestr ~= " – {@week[7]<date>.day} {@month[@week[7]<date>.month]} {@week[7]<date>.year} | Year {@week[0]<year>.uc}";

  return qq:to/END/;
  <h1>{$title}</h1>
  <h2>{$datestr}</h2>
  END

}

