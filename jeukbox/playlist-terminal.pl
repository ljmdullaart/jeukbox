#!/usr/bin/perl
use Term::ANSIScreen qw(cls);
use Term::ReadKey;
use List::Util qw/shuffle/;

my ($width_chars, $height_chars, $width_pixels, $height_pixels) = GetTerminalSize();
my $colwidth=int($width_chars/2);


sub uniq (@) {
    my %seen = ();
    grep { not $seen{$_}++ } @_;
}

$lengte=25;

my $playlist='';
my @items;

open (my $ALLMP3, '<',"/links/playlists/allmp3");
my @lines=<$ALLMP3>;
my $pattern='.';
my @page_content;
my $command='nothing';

my $quit=0;
my $page=0;
while ($quit == 0 ){
	undef @page;
	print "Playlist : $playlist\n";
	print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n";
	my $end_i=$#items;
	if ($end_i < $lengte){$end_i=$lengte;}
	my $lnw=int(($colwidth-15)/3);
	my $fmt="%-8d  %-$lnw.$lnw"."s  %-$lnw.$lnw"."s  %-$lnw.$lnw"."s  ";
	my $j=0;
	for my $i (0 .. $end_i){
		my $filename; my $title; my $artist; my $album; my $track;
		($title, $artist, $album) = split /	/, $items[$i];
		if ($i <= $#items){
			printf ($fmt,$i,$title, $artist, $album);
		}
		else {
			printf ($fmt,$i,$title, $artist, $album);
		}
		while (($j<=$#lines) && !($lines[$j+$page] =~/$pattern/i)){ $j++;}
		if ($j <=$#lines){
			($filename, $title, $artist, $album, $track) = split /@/, $lines[$j+$page];
			push @page_content, $j+$page;
			printf ($fmt,$j+$page,$title, $artist, $album);
			$j++;
		}
	
		print "\n";
	}
	print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n";
	print "pattern: $pattern\n";
	print "a number   : Add number to playlist         |d number   : Delete from playlist     | p pattern  : change pattern\n";
	print "+ or n     : Next page                      |-          : Previous page            | s          : Sort unique\n";
	print "r          : Randomize sequence             |w playlist : Write (playlist optional)| l  playlist: Load playlis\n";
	print "x playlist : Save & quit (playlist optional)|q          : Quit, no save            |\n";
	print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n";
	print "Command: ";
	$command=<>;
	cls();
	print "Command: $command\n";
	if (1==0){}
	elsif ($command=~/^([0-9][0-9]*)/) {
		my ($filename, $title, $artist, $album, $track) = split /@/, $lines[$1];
		$title=~s/^ *//;
		$artist=~s/^ *//;
		$album=~s/^ *//;
		push @items,"$artist	$album	$title";
	}
	elsif ($command=~/^r/) {
		my @srt=shuffle @items;
		@items=uniq(@srt);
	}
	elsif ($command=~/^s/) {
		my @srt=sort @items;
		@items=uniq(@srt);
	}
	elsif ($command=~/^\+/) {
		for (my $i=0; $i<$lengte; $i++){
			$page++;
			while (($page<=$#lines) && !($lines[$page] =~/$pattern/i)){ $page++;}
		}
	}
	elsif ($command=~/^n/) {
		for (my $i=0; $i<$lengte; $i++){
			$page++;
			while (($page<=$#lines) && !($lines[$page] =~/$pattern/i)){ $page++;}
		}
	}
	elsif ($command=~/^-/) {
		for (my $i=0; $i<$lengte; $i++){
			$page--;
			while (($page>=0) && !($lines[$page] =~/$pattern/i)){ $page--;}
		}
		if ($page <0){$page=0;}
	}
	elsif ($command=~/^a  *([0-9]*)/) {
		print "$1\n";
		my ($filename, $title, $artist, $album, $track) = split /@/, $lines[$1];
		$title=~s/^ *//;
		$artist=~s/^ *//;
		$album=~s/^ *//;
		push @items,"$artist	$album	$title";
	}
	elsif ($command=~/^d *(.*)/){
		splice @items,$1,1;
	}
	elsif ($command=~/^s *(.*)/){
		my $fn=$1;
		if ("$fn" eq ""){ $fn=$playlist;}
		if ("$fn" eq ""){$fn="My Playlist";}
		$playlist=$fn;
		$fn=~s/ /_/g;
		$fn="/links/playlists/$fn";
		if (open (my $PL, ">", $fn)){
			print $PL "#PLAYLIST $playlist\n";
			for my $i (0 .. $#items){
				print $PL "$items[$i]\n";
			}
			close $PL;
		}
		else { print "ERROR: Cannot open /links/playlists/$fn";}
	}
	elsif ($command=~/^x *(.*)/){
		my $fn=$1;
		if ("$fn" eq ""){ $fn=$playlist;}
		if ("$fn" eq ""){$fn="My Playlist";}
		$playlist=$fn;
		$fn=~s/ /_/g;
		$fn="/links/playlists/$fn";
		if (open (my $PL, ">", $fn)){
			print $PL "#PLAYLIST $playlist\n";
			for my $i (0 .. $#items){
				$items[$i]=~s/^ *//;
				print $PL "$items[$i]\n";
			}
			close $PL;
			$quit=1;
		}
		else { print "ERROR: Cannot open /links/playlists/$fn";}
	}
	elsif ($command=~/^l *(.*)/){
		$playlist=$1;
		my $listfile=$1; $listfile=~s/ /_/g;
		$listfile="/links/playlists/$listfile";
		if (open (my $LF,'<',$listfile)){
			while (<$LF>){
				if (/#PLAYLIST  *(.*)/){
					$playlist=$1;
				}
				else{
					chomp;
					push @items,$_;
				}
			}
			close $LF;
		}
		else {
			print "Cannot open $listfile\n";
		}
	}
			
	elsif ($command=~/^p  *(.*)/) {$pattern=$1;$page=0;}
	elsif ($command=~/^q/) {$quit=1;}
	if ("$pattern" eq ""){$pattern='.';}
	
}
		
	
	
	

