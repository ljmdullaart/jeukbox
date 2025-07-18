#!/usr/bin/perl
use strict;
use warnings;
use POSIX;
use File::Find;
use DBI;
use utf8;
use Text::Unidecode;
use open ':std', ':encoding(UTF-8)';
use Encode qw(decode encode find_encoding);
use Encode::Detect;
use Encode::Guess qw(euc-jp shiftjis iso-2022-jp); # Optional: for more aggressive guessing, but be careful
my $FIXED_OUTPUT_ENCODING = 'UTF-8';

sub old_map2a {
    	my ($text) = @_;
	$text =~ s/^  *//;
	$text =~ s/  *$//;
	$text =~ s/\\x83/f/g;
	$text =~ s/\\x88//g;
	$text =~ s/\\x91/'/g;
	$text =~ s/\\x92/'/g;
	$text =~ s/\\xA0/ /g;
	$text =~ s/\\xA1/!/g;
	$text =~ s/\\xA9/c/g;
	$text =~ s/\\xAB/<</g;
	$text =~ s/\\xB3/3/g;
	$text =~ s/\\xB4/'/g;
	$text =~ s/\\xB9/1/g;
	$text =~ s/\\xBA/0/g;
	$text =~ s/\\xBF/?/g;
	$text =~ s/\\xC0/A/g;
	$text =~ s/\\xC2/A/g;
	$text =~ s/\\xC3/A/g;
	$text =~ s/\\xC6/AE/g;
	$text =~ s/\\xC7/C/g;
	$text =~ s/\\xD1/N/g;
	$text =~ s/\\xD4/O/g;
	$text =~ s/\\xD6/O/g;
	$text =~ s/\\xD8/0/g;
	$text =~ s/\\xDF/ss/g;
	$text =~ s/\\xE0/a/g;
	$text =~ s/\\xE1/a/g;
	$text =~ s/\\xE2/a/g;
	$text =~ s/\\xE4/a/g;
	$text =~ s/\\xE5/a/g;
	$text =~ s/\\xE6/ea/g;
	$text =~ s/\\xE7/c/g;
	$text =~ s/\\xE8/e/g;
	$text =~ s/\\xE9/e/g;
	$text =~ s/\\xEA/e/g;
	$text =~ s/\\xEB/e/g;
	$text =~ s/\\xED/i/g;
	$text =~ s/\\xEE/i/g;
	$text =~ s/\\xEF/i/g;
	$text =~ s/\\xF1/n/g;
	$text =~ s/\\xF3/o/g;
	$text =~ s/\\xF6/o/g;
	$text =~ s/\\xF7/:/g;
	$text =~ s/\\xF9/u/g;
	$text =~ s/\\xFC/u/g;
	$text =~ s/\x\FE/b/g;
    	return unidecode($text);
}

sub map2a {
 my ($input_string_bytes) = @_;

	$input_string_bytes =~ s/^  *//;
	$input_string_bytes =~ s/  *$//;
    my $decoded_string;

    # 1. Attempt to decode as UTF-8 first.
    # This is crucial because a truly UTF-8 string MUST be decoded as UTF-8.
    # We suppress the 'UTF-8 does not map to Unicode' warnings, as they are expected
    # when testing non-UTF-8 strings.
    {
        no warnings 'utf8'; # Temporarily suppress warnings for invalid UTF-8 sequences
        $decoded_string = eval { decode('UTF-8', $input_string_bytes, Encode::FB_CROAK) };
    }

    if (defined $decoded_string) {
        # Successfully decoded as UTF-8, so encode to the fixed output
        return encode($FIXED_OUTPUT_ENCODING, $decoded_string);
    }

    # 2. If not valid UTF-8, assume it's one of the common extended ASCII encodings.
    # Iterate through them. cp1252 is often a good first guess for Windows environments.
    # iso-8859-1 (Latin-1) is a common standard.
    my @fallback_encodings = (
        'cp1252',       # Windows Latin-1 (common on Windows systems)
        'iso-8859-1',   # Latin-1 (common Unix/Linux/Web default)
        'iso-8859-15',  # Latin-9 (adds Euro symbol and some French/Finnish chars)
        'cp850',        # DOS Latin 1 / Western European
        'macroman',     # Old Macintosh encoding
        # Add more if you suspect other regions/systems:
        # 'iso-8859-2', # Central European
        # 'koi8-r',     # Cyrillic
    );
    foreach my $encoding (@fallback_encodings){
        eval {
            $decoded_string = decode($encoding, $input_string_bytes, Encode::FB_CROAK);
            # If decode didn't die, it's successfully decoded.
            return encode($FIXED_OUTPUT_ENCODING, $decoded_string);
        };
    }

    # 3. Fallback: If no common encoding worked, something is truly ambiguous or non-text.
    # This step ensures a string is *always* returned in the target encoding,
    # even if characters are replaced.
	return $input_string_bytes;
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
        if (/=== TIT2/) { s/===.*: //; $title = old_map2a($_); }
        elsif (/=== TRCK/) { s/===.*: //; $track = old_map2a($_); }
        elsif (/=== TALB/) { s/===.*: //; $album = old_map2a($_); }
        elsif (/=== TPE1/) { s/===.*: //; $performer = old_map2a($_); }
    }

    $track =~ s/\/.*//;
    $track = $track =~ /^[0-9]+$/ ? $track : 0;
    return ($title, $performer, $album, $track);
}

sub listmp3 {
    find({ wanted =>\&wanted, follow=>1}, "/links/cdtracks");
}

listmp3();
