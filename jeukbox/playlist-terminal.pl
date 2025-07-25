#!/usr/bin/perl
use strict;
use warnings;
use Term::ANSIScreen qw(cls);
use Term::ReadKey;
use List::Util qw/shuffle/;
use DBI;
use Data::Dumper;

my ($width_chars, $height_chars, $width_pixels, $height_pixels) = GetTerminalSize();
my $colwidth=int($width_chars/2);


sub uniq (@) {
    my %seen = ();
    grep { not $seen{$_}++ } @_;
}

my $db_file='/links/cdtracks/music.db';

sub query_db {
        my ($sql, @bind_params) = @_;
        my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });
        my $sth = $dbh->prepare($sql);
        unless ($sth) { $dbh->disconnect; }
        if (!$sth->execute(@bind_params)){
		print "Execute failed\n";
                $sth->finish;
                $dbh->disconnect;
        }
        my @results;
        while (my $row = $sth->fetchrow_hashref) {
                push @results, $row;
        }
        $sth->finish;
        $dbh->disconnect;
	
        return \@results;
}

my $lengte=25;

my $playlist='';
my @items;

my $reflines=query_db("SELECT * FROM mp3");
my @lines=@$reflines;
my $maxlines=$#lines;
print "-------------------------\n";

my $pattern='.';
my @page_content;
my $command='nothing';

my $filename; my $title; my $artist; my $album; my $track;
my $quit=0;
my $page=0;
while ($quit == 0 ){
	undef @page_content;;
	print "Playlist : $playlist\n";
	print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n";
	my $end_i=$#items;
	if ($end_i < $lengte){$end_i=$lengte;}
	my $lnw=int(($colwidth-15)/3);
	my $fmt="%-6d  %-$lnw.$lnw"."s  %-$lnw.$lnw"."s  %-$lnw.$lnw"."s  ";
	my $j=0;
	for (my $i =0; $i<= $end_i ; $i++){
		($title, $artist, $album) = ('','','');
		($artist, $album,$title) = split /	/, $items[$i] if defined $items[$i];
		chomp $title;
		my $fnameref=query_db("SELECT file FROM mp3 WHERE title= ? AND artist=? AND album= ?",$title,$artist,$album);
		my @fname_a=@$fnameref;
		my $fname=$fname_a[0]{'file'};
		if (defined $fname){
			if (-e $fname){
				print '* ';
			}
			else {
				print '- ';
			}
		}else{
			print '  ';
		}
		if ($i <= $#items){
			printf ($fmt,$i,$title, $artist, $album);
		}
		else {
			printf ($fmt,$i,$title, $artist, $album);
		}
		$title=$lines[$j+$page]{'title'};
		$album=$lines[$j+$page]{'album'};
		$artist=$lines[$j+$page]{'artist'};
		$title='' unless defined $title;
		$artist='' unless defined $artist;
		$album='' unless defined $album;
		while (($j<=$maxlines) && !("$title $album $artist"=~/$pattern/i)){
			$j++;
			$title=$lines[$j+$page]{'title'};
			$album=$lines[$j+$page]{'album'};
			$artist=$lines[$j+$page]{'artist'};
			$title='' unless defined $title;
			$artist='' unless defined $artist;
			$album='' unless defined $album;
		}
		if ($j <=$#lines){
			$title=$lines[$j+$page]{'title'};
			$album=$lines[$j+$page]{'album'};
			$artist=$lines[$j+$page]{'artist'};
			$title='' unless defined $title;
			$artist='' unless defined $artist;
			$album='' unless defined $album;
			push @page_content, $j+$page;
			chomp $album;
			printf ($fmt,$j+$page,$title, $artist, $album);
			$j++;
		}
		else {$i=999999999999;}
		
	
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
		$title=$lines[$1]{'title'};
		$album=$lines[$1]{'album'};
		$artist=$lines[$1]{'artist'};
		$title='' unless defined $title;
		$artist='' unless defined $artist;
		$album='' unless defined $album;
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
			$title=$lines[$page]{'title'};
			$album=$lines[$page]{'album'};
			$artist=$lines[$page]{'artist'};
			$title='' unless defined $title;
			$artist='' unless defined $artist;
			$album='' unless defined $album;

			while (($page<=$#lines) && !("$title $album $artist" =~/$pattern/i)){
				$page++;
				$title=$lines[$page]{'title'};
				$album=$lines[$page]{'album'};
				$artist=$lines[$page]{'artist'};
				$title='' unless defined $title;
				$artist='' unless defined $artist;
				$album='' unless defined $album;
			}
		}
	}
	elsif ($command=~/^n/) {
		for (my $i=0; $i<$lengte; $i++){
			$page++;
			$title=$lines[$page]{'title'};
			$album=$lines[$page]{'album'};
			$artist=$lines[$page]{'artist'};
			$title='' unless defined $title;
			$artist='' unless defined $artist;
			$album='' unless defined $album;

			while (($page<=$#lines) && !("$title $album $artist" =~/$pattern/i)){
				$page++;
				$title=$lines[$page]{'title'};
				$album=$lines[$page]{'album'};
				$artist=$lines[$page]{'artist'};
				$title='' unless defined $title;
				$artist='' unless defined $artist;
				$album='' unless defined $album;
			}
		}
	}
	elsif ($command=~/^-/) {
		for (my $i=0; $i<$lengte; $i++){
			$page--;
			$title=$lines[$page]{'title'};
			$album=$lines[$page]{'album'};
			$artist=$lines[$page]{'artist'};
			$title='' unless defined $title;
			$artist='' unless defined $artist;
			$album='' unless defined $album;
			while (($page<=$#lines) && !("$title $album $artist" =~/$pattern/i)){
				$page--;
				$title=$lines[$page]{'title'};
				$album=$lines[$page]{'album'};
				$artist=$lines[$page]{'artist'};
				$title='' unless defined $title;
				$artist='' unless defined $artist;
				$album='' unless defined $album;
			}
		}
		if ($page <0){$page=0;}
	}
	elsif ($command=~/^a  *([0-9]*)/) {
		print "$1\n";
		my $title=$lines[$1]{'title'};
		my $album=$lines[$1]{'album'};
		my $artist=$lines[$1]{'artist'};
		$title='' unless defined $title;
		$artist='' unless defined $artist;
		$album='' unless defined $album;
		$title=~s/^ *//;
		$artist=~s/^ *//;
		$album=~s/^ *//;
		push @items,"$artist	$album	$title";
	}
	elsif ($command=~/^d *(.*)/){
		splice @items,$1,1;
	}
	elsif ($command=~/^w *(.*)/){
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
		
	
	
	

