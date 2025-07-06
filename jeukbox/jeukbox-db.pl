#!/usr/bin/perl
use strict;
use warnings;
use POSIX;
use File::Find;
use DBI;
use utf8;
use Text::Unidecode;
use open ':std', ':encoding(UTF-8)';

sub map2a {
    	my ($text) = @_;
	$text=unidecode($text);
$text =~ tr/
        \xC0\xC1\xC2\xC3\xC4\xC5\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF
        \xE0\xE1\xE2\xE3\xE4\xE5\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF
    /
        AAAAAACEEEEIIIIIDNOOOOUUUUYTHss
        aaaaaaceeeeiiiiioooooouuuuythyy
    /;
    	return unidecode($text);
}

# Database
my $dbfile = "music.db";
my $db = DBI->connect("dbi:SQLite:dbname=$dbfile") or die $DBI::errstr;

# Create tables if they don't exist
my $schema = "
CREATE TABLE IF NOT EXISTS mp3 (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    file    TEXT,
    title   TEXT,
    artist  TEXT,
    album   TEXT,
    track   INTEGER
);
CREATE TABLE IF NOT EXISTS config (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    field   TEXT,
    value   TEXT
);
";
$db->do($schema) or die $db->errstr;

# Database operations
sub db_execute {
        my ($sql, @bind_params) = @_;
        my $sth = $db->prepare($sql);
        unless ($sth) {print "STH fails\n";}
        return $sth;
}

sub db_insert {
    	my $sth=db_execute("INSERT INTO mp3 (file, title, artist, album, track) VALUES ( ? , ? , ? , ?, ? )");
	if (!$sth->execute(@_)){
		print "execute failed\n";
	}
}
	

sub db_value {
    my ($sql) = @_;
    my $sth = db_execute($sql);
    my @row = $sth->fetchrow_array();
    return @row ? $row[0] : undef;
}

# File processing
sub wanted {
    return unless /\.mp3$/;
    my $file_path = $File::Find::name;
    my $id = db_value("SELECT id FROM mp3 WHERE file LIKE '$file_path'");
    return if defined $id;

    my ($title, $performer, $album, $track) = extract_id3_info($file_path);
    print "$file_path@ $title@ $performer@ $album@ $track\n";
    db_insert($file_path, $title, $performer, $album, $track);
}

sub extract_id3_info {
    my ($file_path) = @_;
    my $title = $file_path;
    my $performer = $file_path;
    my $album = $file_path;
    my $track = 1;

    $title =~ s/.mp3$//;
    $performer =~ s/.*cdtracks.//;
    $performer =~ s/\/.*//;
    $album =~ s/.*$performer\///;
    $album =~ s/\/$title.mp3//;

    my @id3 = `id3info '$file_path'`;
    for (@id3) {
        chomp;
        if (/=== TIT2/) { s/===.*: //; $title = map2a($_); }
        elsif (/=== TRCK/) { s/===.*: //; $track = map2a($_); }
        elsif (/=== TALB/) { s/===.*: //; $album = map2a($_); }
        elsif (/=== TPE1/) { s/===.*: //; $performer = map2a($_); }
    }

    $track =~ s/\/.*//;
    $track = $track =~ /^[0-9]+$/ ? $track : 0;
    return ($title, $performer, $album, $track);
}

sub listmp3 {
    find({ wanted =>\&wanted, follow=>1}, "/links/cdtracks");
}

listmp3();
