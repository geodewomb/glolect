#!usr/local/bin/perl6
use v6;


my $root = '/';
$root = slurp('etc/path.txt').chomp if 'etc/path.txt'.IO.e;

my @xday = <_ Monday Tuesday Wednesday Thursday Friday Saturday Sunday>;
my @day = <_ Mon Tues Wed Thur Fri Sat Sun>;
my @xmon = <NovDec January February March April May June July August September October November December>;
my @mon = <_ Jan Feb March April May June July Aug Sept Oct Nov Dec>;

prepare_directories();

process_data('lectdat.txt');

make_browser();

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

 $ref = $ref.subst('&', ' & ', :global);

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
    my $eitheror = '<p class="eitheror">/ ' ~ @eitheror.join("<br><span>or</span> ") ~ " /</p>";

    %d<scrips> = $/.prematch ~ $eitheror ~ $/.postmatch;
  }

  # divide scripture string and tag with html
  my @scrips = %d<scrips>.split(';');
  for @scrips {
    given $_ {
      when /'[' (.+) ']'/ { $_ = "<h3>" ~ $0.Str ~ "</h3>"; }
      when /^AM$||^PM$||NEXT/   { $_ = "<h4>" ~ $_ ~ "</h4>"; }
      when /'<p class'/   { next; }
      when /^'(' (.+) ')'$/ { $_ = '<p class="glo"><span>+</span> ' ~ gateway($0.Str) ~ " <span>+</span></p>"; } 
      default             { $_ = "<p>" ~ gateway($_) ~ "</p>"; }
    }
  }
  %d<scrips> = @scrips.join("\n");
  
  # make html chunk for a day
  return qq:to/END/;
  <h1>{@xday[%d<date>.day-of-week]}</h1>
  <h2>{%d<date>.day} {@mon[%d<date>.month]}</h2>
  <h3>{%d<feast>}</h3>
  {%d<scrips>}
  END
}

sub indexer($html,$title,$season) {

  return qq:to/END/;
  <!DOCTYPE html>
  <html>
  <title>Glo Lect | {$title}</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://fonts.googleapis.com/css?family=Istok+Web:400,400i,700" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css?family=Lato:400,700" rel="stylesheet">  
  <link rel="stylesheet" type="text/css" href="{$root}/etc/styles.css"> 
  <body class="{$season}">
  <svg id="swipe-l" viewBox="0 0 40 90" preserveAspectRatio="none"><polygon points="0 0 40 0 0 90" fill="#ffffff00" /></svg>
  <svg id="swipe-r" viewBox="0 0 540 90" preserveAspectRatio="none"><polygon points="0 0 500 0 540 90 0 90" fill="#ffffff00" /></svg>
  <nav class="generic">
  <a class="generic" href="{$root}">Glo Lec<span class="bigger">+</span></a>
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
  <!--#include virtual="{$root}/today.html" -->
  $html
  </body>
  </html>
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

sub make_browser {

  my @split;

  for ('a','b','c') -> $y {

    my $season = 'advent';
    my $monum = 0;
    my $flip = 1;

    my @by-s = '<div id="row1">', '<article class="advent">', '<h1>ADVENT</h1>';
    my @by-m = '<div id="row1">', '<article class="novdec">', '<h1> NOV / DEC</h1>';
  
    for "year-$y/yeardat.txt".IO.lines -> $line {
      my ($w, $s, $f, $m, $z) = $line.split('|');
      once { push @split, ($z ~ '/' ~ $z+1, $y); }

      unless $s eq $season { 
        push @by-s, qq|</article>|;
        given $s {
          when 'lent' { push @by-s, qq|</div>\n<div id="row2">|; proceed; }
          when 'ordinary' { push @by-s, qq|</div>\n<div id="row3">|; proceed; }
          default { push @by-s, qq|<article class="{$s}">\n<h1>{$s.uc}</h1>|; }
        }
        $season = $s;
      }
      unless $m == $monum or ($monum == 0 and $m > 10) { 
        push @by-m, qq|</article>|;
        given $m {
          when 4 { push @by-m, qq|</div>\n<div id="row2">|; proceed; }
          when 8 { push @by-m, qq|</div>\n<div id="row3">|; proceed; }
          default { push @by-m, qq|<article class="m{@xmon[$m].lc}">\n<h1>{@xmon[$m].uc}</h1>|; }
        }
        $monum = $m; 
      }
      my $svg = make_svg($f,"year-$y/week-$w",$flip);
      push @by-s, $svg;
      push @by-m, $svg;

      $flip = 1 - $flip;
    }
    push @by-s, "</article>\n</div>";
    push @by-m, "</article>\n</div>";

    for ("year-$y/by-season","year-$y/by-month") { mkdir $_ unless $_.IO.e; }
    
    spurt "year-$y/by-season.html", @by-s.join("\n");
    spurt "year-$y/by-month.html", @by-m.join("\n");
  
  }
 
  mkdir 'browse' unless 'browse'.IO.e;

  @split.sort;

  for ('by-season','by-month') -> $type {

    for ('a','b','c') -> $y {
      my $summary = slurp("etc/info-$y.txt");
      my @links;
      
      my $split;
      for @split { $split = $_[0] if $_[1] eq $y; }

      for (@split) -> $year {
        if $year[1] eq $y {
          push @links, qq|<a class="selected" href=""><h1>Year {$year[1].uc}</h1><h2>{$year[0]}</h2></a>|;
        } else {
          push @links, qq|<a href="{$root}/year-{$year[1]}/{$type}"><h1>Year {$year[1].uc}</h1><h2>{$year[0]}</h2></a>|;
        }
      }
      push @links, qq|<div id="options">\n<a class="go-archive" href="{$root}/browse/archive">past years</a>|;
      if $type eq 'by-season' {
        push @links, '<a class="selected" href=""><h1>By Season</h1></a>';
        push @links, qq|<a href="{$root}/year-{$y}/by-month"><h1>By Month</h1></a>|;
      }
      elsif $type eq 'by-month' {
        push @links, qq|<a href="{$root}/year-{$y}/by-season"><h1>By Season</h1></a>|;
        push @links, '<a class="selected" href=""><h1>By Month</h1></a>';
      } 
     
      my $html = qq:to/END/;
      
      <main>
      <section class="menu generic">
      <div id="years">
      {@links.join("\n")}
      </div>
      </div>
      <div id="summary">
      $summary
      </div>
      </section>
      <section class="generic">
      <div id="morelinks">
      <a href="{$root}/year-{$y}/feasts">Sundays + Feast Days</a>
      <a href="{$root}/year-{$y}">All of {$split}</a>
      </div>
      </section>
      <section class="yeardat">
      <!--#include virtual="{$root}/year-{$y}/{$type}.html" -->
      </section>
      </main>
      END
      
      spurt "year-$y/$type/index.shtml", indexer($html,"Browse Year {$y.uc}",'generic');
      copy "etc/tribar.html", "year-$y/$type/tribar.html";
    }
  } 
}

sub make_svg($season,$link,$flip) {

  my @out = "0 0 22.5 40 45 0", "0 40 22.5 0 45 40";
  my @in = "7.5 3 22.5 17.5 37.5 3", "7.5 37 22.5 22.5 37.5 37";

  return qq:to/END/
  <svg class="{$season}" viewBox="0 0 45 40" height="40px" width="45px">
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
    
    my $svg = make_svg(@week[0]<feast>,$root,0);
  
    my $html = qq:to/END/;
    <section class="today {@week[0]<feast>}">
    <a href="{$root}" class="date">
    <h1>TODAY'S SCRIPTURES</h1>
    $svg
    <h1>{@xday[@week[$d]<date>.day-of-week].uc} {@week[$d]<date>.day} {@xmon[@week[$d]<date>.month].uc}</h1>
    </a>
    <article class="scrips">
    {@week[$d]<scrips>}
    </article>
    </section>
    END
    spurt "$dir/index.html", $html;
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

  my $regist = "{@week[0]<num>}|{@week[0]<season>}|{@week[0]<feast>}|{@week[7]<date>.month}|{@week[7]<date>.year}\n";
  spurt "year-{@week[0]<year>}/yeardat.txt", $regist, :append;

}

sub prepare_directories {
  
  for ('year-a','year-b','year-c','browse') {
    mkdir $_ unless $_.IO.e;
    unlink "$_/yeardat.txt";
    
  }

  
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
          when /NATIV||NAME||PROP||THANKS/ { }
          when /(HOLY||GOOD||MAU||EAS).+DAY/ { %day<season> = "holyweek"; proceed; }
          default { @workweek[0]<feast> = %day<feast>.comb(/<:L>+/).join('').lc unless @workweek[0]<feast>; }
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
        @workweek[0]<season> = $line.split(' ').join.lc;
        @workweek[0]<count> = 1;
       
        # setup and reset year on year change 
        if $line.lc ~~ /advent/ {
          redirect_final_week(@workweek[0]<year>,@workweek[0]<num>);
          @workweek[0]<num> = 1;
          @workweek[0]<register> = '';
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
  if $hta ~~ / $root'/year-'$y'/week-'(\d\d)\s / { spurt ".htaccess", $hta.subst($0, $w, :g); }
  else { spurt ".htaccess", "Redirect 302 $root/year-$y/week-$w $root/year-$z/week-1\n", :append; }
  
  $hta = slurp(".htaccess");
  if $hta ~~/ '/year-'$y'/week-'(\d\d)\n / { spurt ".htaccess", $hta.subst($0, $w - 1, :g); }
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

  copy "year-$y/by-season/index.shtml", "browse/index.shtml";

  copy "{$today.year}/{$today.month}/{$today.day}/index.html", "today.html";   
  
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

  my $title = "Year {%i<year>.uc} | Week {%i<num>}";
  
  my $html = qq:to/END/;
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

  return indexer($html,$title,%i<season>);
}

sub weekly_info(@week) {

  my @numth = <th st nd rd th th th th th th
               th th th th th th th th th th
               th st nd rd th th th th th th>;
  my $num = @week[0]<count>;

  my $title;
  given @week[0]<feast> {
    when /ashwednesday/ { $title = "Week of Ash Wednesday"; }
    when /palmsunday/ { $title = "Week of Palm Sunday"; }
    when /holymonday||easterday/ { $title = "Holy Week and Easter Sunday"; }
    when /baptism/ { $title = "Week of the Baptism of the Lord"; }
    when /epiphanyday/ { $title = "Week of Epiphany Day"; }
    when /allsaints/ { $title = "Week of All Saints Day"; }
    when /christtheking/ { $title = "Week of Christ the King Sunday"; }
    when /ordinary/ { $title = "{$num}{@numth[$num]} Sunday after Pentecost"; }
    when /epiphany||easter/ { $title = "{$num}{@numth[$num]} Sunday after {$_.wordcase}"; }
    when /ascension||thanksgiving/ { $title = "Week of {$_.wordcase} Day"; }
    when /trinity||transfig||pentecost/ { $title = "Week of {$_.wordcase} Sunday"; } 
    default { $title = "{$num}{@numth[$num]} Week of {$_.wordcase}"; }
  }

  my $datestr = "{@week[1]<date>.day} {@xmon[@week[1]<date>.month]}";
  if @week[1]<date>.year != @week[7]<date>.year { $datestr ~= " {@week[1]<date>.year}"; }
  $datestr ~= " – {@week[7]<date>.day} {@xmon[@week[7]<date>.month]} {@week[7]<date>.year} | Year {@week[0]<year>.uc}";

  return qq:to/END/;
  <h1>{$title}</h1>
  <h2>{$datestr}</h2>
  END

}

