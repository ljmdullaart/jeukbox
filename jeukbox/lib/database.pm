package database;

use strict;
use warnings;
use DBI;
use JSON;
use Exporter 'import';
use File::Spec;
use POSIX qw(strftime);

# Export database subroutines
our @EXPORT_OK = qw(
	get_artists
	get_albums
	get_album
	get_titles
	get_file
	get_txt
	get_artists_from_song
	get_artists_from_album
);

# Path to the SQLite3 database
my @dirs = ('.', '..', File::Spec->catdir('..', '..'),'/links/cdtracks');

my $db_file;
for my $dir (@dirs) {
    my $path = File::Spec->catfile($dir, 'music.db');
    if (-e $path) {
        $db_file = $path;
        last;
    }
}

############################################################################################################
#                                  _                               
#   __ _  ___ _ __   ___ _ __ __ _| |   __ _ _   _  ___ _ __ _   _ 
#  / _` |/ _ \ '_ \ / _ \ '__/ _` | |  / _` | | | |/ _ \ '__| | | |
# | (_| |  __/ | | |  __/ | | (_| | | | (_| | |_| |  __/ |  | |_| |
#  \__, |\___|_| |_|\___|_|  \__,_|_|  \__, |\__,_|\___|_|   \__, |
#  |___/                                  |_|                |___/ 

sub query_db {
	my ($format, $sql, @bind_params) = @_;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });
	my $sth = $dbh->prepare($sql);
	unless ($sth) { $dbh->disconnect; }
	if (!$sth->execute(@bind_params)){
		$sth->finish;
		$dbh->disconnect;
	}
	if ($format eq "value") {
		my $row = $sth->fetchrow_arrayref;
		$sth->finish;
		$dbh->disconnect;
		return $row ? $row->[0] : undef;  # Return first column's value, or undef if no result
	}
	my @results;
	while (my $row = $sth->fetchrow_hashref) {
		push @results, $row;
	}
	$sth->finish;
	$dbh->disconnect;
	return $format eq "json" ? encode_json(\@results) : \@results;
}

############################################################################################################

sub get_artists {
	(my $arg)=@_;
	$arg='hash' unless defined $arg;
	return query_db ($arg,"SELECT DISTINCT artist FROM mp3 ORDER BY artist");
}

sub get_artists_from_album {
	(my $arg,my $album)=@_;
	$arg='hash' unless defined $arg;
	if (defined $album){
		return query_db ($arg,"SELECT DISTINCT artist FROM mp3 WHERE album = ? ORDER BY artist",$album);
	}
	else {
		return query_db ($arg,"SELECT DISTINCT artist FROM mp3 ORDER BY artist");
	}
}

sub get_artists_from_song {
	(my $arg,my $song)=@_;
	$arg='hash' unless defined $arg;
	if (defined $song){
		return query_db ($arg,"SELECT DISTINCT artist FROM mp3 WHERE title = ? ORDER BY artist",$song);
	}
	else {
		return query_db ($arg,"SELECT DISTINCT artist FROM mp3 ORDER BY artist");
	}
}

sub get_albums {
	(my $artist,my $fmt)=@_;
	my $result;
	$fmt='hash' unless defined $fmt;
	if ((defined $artist) && ($artist ne '')){
		$result=query_db('json',"SELECT DISTINCT album FROM mp3 WHERE artist = ? ORDER BY album",$artist)
	}
	else {
		$result=query_db('json',"SELECT DISTINCT album FROM mp3 ORDER BY album")
	}
	return $result;
}

sub get_titles {
	(my $artist,my $album,my $fmt)=@_;
	my $result;
	$fmt='hash' unless defined $fmt;
	my $whereclause='WHERE 1=1 ';
	my @xtraarg= ();
	my $orderby='ORDER BY title';
	if ((defined $artist)&&($artist ne '')&&($artist ne 'null')) {
		$whereclause="$whereclause AND artist = ? ";
		$orderby='ORDER BY album,track';
		push @xtraarg,$artist;
	}
	if ((defined $album )&&($album  ne '')) {
		$whereclause="$whereclause AND album  = ? ";
		$orderby='ORDER BY album,track';
		push @xtraarg,$album;
	}
	$result=query_db('json',"SELECT DISTINCT title FROM mp3 $whereclause $orderby",@xtraarg);
	return $result;
}
sub get_txt {
	(my $artist,my $album,my $title)=@_;
	$artist='' unless defined $artist;
	$album ='' unless defined $album ;
	$title ='' unless defined $title ;
	$artist='' if ( $artist eq 'null');
	$album ='' if ( $album  eq 'null');
	$title ='' if ( $title  eq 'null');
	$artist='' if ( $artist =~/^Unknown/);
	$album ='' if ( $album  =~/^Unknown/);
	$title ='' if ( $title  =~/^Unknown/);
	my @xtraarg= ();
	my $whereclause='WHERE 1=1 '; 
	if ((defined $artist)&&($artist ne '')) { $whereclause="$whereclause AND artist = ? "; push @xtraarg,$artist;}
	if ((defined $album)&&($album ne '')) { $whereclause="$whereclause AND album = ? "; push @xtraarg,$album;}
	if ((defined $title )&&($title  ne '')) { $whereclause="$whereclause AND title  = ? "; push @xtraarg,$title; }
	my $txtfile=query_db('value',"SELECT file FROM mp3 $whereclause  LIMIT 1", @xtraarg);
	$txtfile=~s/mp3$/txt/;
	return $txtfile;
}
sub get_file {
	(my $artist,my $album,my $title)=@_;
	$artist='' unless defined $artist;
	$album ='' unless defined $album ;
	$title ='' unless defined $title ;
	$artist='' if ( $artist eq 'null');
	$album ='' if ( $album  eq 'null');
	$title ='' if ( $title  eq 'null');
	$artist='' if ( $artist =~/^Unknown/);
	$album ='' if ( $album  =~/^Unknown/);
	$title ='' if ( $title  =~/^Unknown/);
	my @xtraarg= ();
	my $whereclause='WHERE 1=1 '; 
	if ((defined $artist)&&($artist ne '')) { $whereclause="$whereclause AND artist = ? "; push @xtraarg,$artist;}
	if ((defined $album)&&($album ne '')) { $whereclause="$whereclause AND album = ? "; push @xtraarg,$album;}
	if ((defined $title )&&($title  ne '')) { $whereclause="$whereclause AND title  = ? "; push @xtraarg,$title; }
	return query_db('value',"SELECT file FROM mp3 $whereclause  LIMIT 1", @xtraarg);
}

sub get_album {
	(my $artist,my $title)=@_;
	my $whereclause='WHERE 1=1 ';
	my @xtraarg= ();
	if ((defined $artist)&&($artist ne '')) { $whereclause="$whereclause AND artist = ? "; push @xtraarg,$artist;}
	if ((defined $title )&&($title  ne '')) { $whereclause="$whereclause AND title  = ? "; push @xtraarg,$title; }
	my $result=query_db('json',"SELECT DISTINCT album FROM mp3 $whereclause ORDER BY album,track",@xtraarg);
	return $result;
}
	


1;
