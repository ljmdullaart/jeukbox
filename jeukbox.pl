#!/usr/bin/perl
use strict;
use POSIX;
use File::Find;
use DBI;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;
use Term::ANSIScreen qw(cls);
use Tk;
use Tk::Text::Viewer;
use Proc::ProcessTable;

# __     __         _       _     _           
# \ \   / /_ _ _ __(_) __ _| |__ | | ___  ___ 
#  \ \ / / _` | '__| |/ _` | '_ \| |/ _ \/ __|
#   \ V / (_| | |  | | (_| | |_) | |  __/\__ \
#    \_/ \__,_|_|  |_|\__,_|_.__/|_|\___||___/
#         
# Database
my $dbfile="music.db";		# Name of the database 
my $db;				# Database handler
my $schema;			# Schema used for the definition of tables
my $db_sth;
# Play songs
my $kidpid;			# PID of the player when it is playing
my $playing=0;			# Flag to see is a song is playing at the moment
my @play_queue;			# Queue fro songs to be played
my @title_queue;		# same queue, but only the titles.
# Tk objects
my $mw;				# Main winndow
my $menu_bar;			#   The menu bar at the top
my $menu_file;			#     The "file" menu in the menu bar
my $frame_message;		#   A message frame for infoemation
my $frame_main;			#   The main frame where everything is located
my $frame_artist;		#      The frame for the list of artists
my $listbox_artist;		#        Listbox with the relevant artists
my $frame_album;		#      The frame for the list of albums
my $listbox_album;		#        Listbox with the relevant albums
my $frame_title;		#      The frame for the list of song titles
my $listbox_title;		#        Listbox with the relevant titles
my $frame_playlist;		#      The frame for the list of playlists
my $frame_actions;		#      The frame for the list of other actions
my $frame_inactions;		#        A frame to group the actions. used for a seperate destroy
my $frame_buttons;		#          Frame for action buttons
my $listbox_playing;		#          List box for the play-queue
my $frame_text;			#      Frame with songtext if available
my $textbox;			#        Box with songtext
# Other variables
my $selected_artist='__ALL_ARTISTS__';	# The artist, when selected
my $filter_artist='';			# a filter for the artist
my $selected_album='_ALL_ALBUMS__';	# The album, when selected
my $filter_album='';			# a filter for the album
my $selected_title='';			# The title, when selected
my $filter_title='';			# a filter for the title
my $nowplaying_artist;
my $nowplaying_album;
my $nowplaying_song;
my $nowplaying_file;

#      _       _	_		    
#   __| | __ _| |_ __ _| |__   __ _ ___  ___ 
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#   

$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
	or die $DBI::errstr;

$schema='';
$schema="
CREATE TABLE IF NOT EXISTS mp3 (
	id	integer primary key autoincrement,
	file	string,
	title	string,
	artist	string,
	album	string,
	track	integer,
	maptitle	string,
	mapartist	string,
	mapalbum	string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS config (
	id	integer primary key autoincrement,
	field	string,
	value	string
	);
";
$db->do($schema) or die $db->errstr;

sub db_dosql{
	(my $sql)=@_;
	if ($db_sth = $db->prepare($sql)){
		$db_sth->execute();
		return 0;
	}
	else {
		print "Prepare failed for $sql\n";
		return 1;
	}
}

sub db_getrow {
	my @row;
	if (@row = $db_sth->fetchrow()){
		return @row;
	}
	else {
		return ();
	}
}

sub db_value {
	(my $sql)=@_;
	my @row;
	if ($db_sth = $db->prepare($sql)){
		$db_sth->execute();
		if (@row = $db_sth->fetchrow()){
			return $row[0];
		}
		else {
			print "Empty row for $sql\n";
			return undef;
		}
		db_close();
	}
	else {
		print "Prepare failed for $sql\n";
		return undef;
	}
}
#      _       __             _ _       
#   __| | ___ / _| __ _ _   _| | |_ ___ 
#  / _` |/ _ \ |_ / _` | | | | | __/ __|
# | (_| |  __/  _| (_| | |_| | | |_\__ \
#  \__,_|\___|_|  \__,_|\__,_|_|\__|___/
#  

sub set_default {
	(my $field, my $value)=@_;
	my $id;
	my $oval=db_value("SELECT value FROM config WHERE field='$field'");
	if (!(defined $oval)){
		my $id=db_value("SELECT id FROM config WHERE field='$field'");
		if(!(defined($id))){
			db_dosql("INSERT INTO config (field,value) VALUES ('$field','$value')");
		}
		else {
			db_dosql("UPDATE config SET value='$value' WHERE field='$field'");
		}
	}
}

set_default ('player','/usr/local/bin/monoplay');
set_default ('dbread','no');






#   __ _           _                  _____     
#  / _(_)_ __   __| |  _ __ ___  _ __|___ / ___ 
# | |_| | '_ \ / _` | | '_ ` _ \| '_ \ |_ \/ __|
# |  _| | | | | (_| | | | | | | | |_) |__) \__ \
# |_| |_|_| |_|\__,_| |_| |_| |_| .__/____/|___/
#                               |_|   
sub wanted {
	my $title;
	my $performer;
	my $album;
	my $track;
	my $id;	
	if (/\.mp3$/){
		#print "$File::Find::name = $_\n";
		my $search=$File::Find::name;
		$search=~s/'/_/g;
		$id=db_value("SELECT id FROM mp3 WHERE file like '$search'");
		if (! defined($id)){
			$title=$_;
			$performer=$File::Find::name;
			$album=$File::Find::name;
			$title=~s/.mp3$//;
			$performer=~s/.*cdtracks.//;
			$performer=~s/\/.*//;
			$album=~s/.*$performer\///;
			$album=~s/\/$title.mp3//;
			$title=~s/_/ /g;
			$performer=~s/_/ /g;
			$track=1;
			if ($album=~/mp3$/){$album='';}
			my @id3=`id3info '$File::Find::name'`;
			for (@id3){
				chomp;
				if (/=== TIT2/){
					s/===.*: //;
					$title=$_;
				}
				elsif (/=== TRCK/){
					s/===.*: //;
					$track=$_;
					$track=~s/\/.*//;
				}
				elsif (/=== TALB/){
					s/===.*: //;
					$album=$_;
				}
				elsif (/=== TPE1/){
					s/===.*: //;
					$performer=$_;
				}
			}
			undef @id3;
			print "    Title    : $title\n";
			print "    Performer: $performer\n";
			print "    Album    : $album\n";
			print "    Track    : $track\n";
			$title=~s/'/''/g;
			$performer=~s/'/''/g;
			$album=~s/'/''/g;
			if (!($track=~/^[0-9][0-9]*$/)){$track=0;}
			db_dosql("INSERT INTO mp3 ( file, title, artist, album, track) VALUES ('$File::Find::name','$title','$performer','$album',$track)");
		}
		else {
			print "$id $File::Find::name\n";
		}
	}
}

sub listmp3 {
	find(\&wanted, @_);
}

if (db_value("SELECT value FROM config WHERE field='dbread'") eq 'no' ){
	listmp3 ("/home/ljm/Dropbox/cdtracks");
	db_dosql("UPDATE config SET value='yes' WHERE field='dbread'");
}

#        _                                             
#  _ __ | | __ _ _   _    __ _   ___  ___  _ __   __ _ 
# | '_ \| |/ _` | | | |  / _` | / __|/ _ \| '_ \ / _` |
# | |_) | | (_| | |_| | | (_| | \__ \ (_) | | | | (_| |
# | .__/|_|\__,_|\__, |  \__,_| |___/\___/|_| |_|\__, |
# |_|            |___/                           |___/ 

$SIG{CHLD} = sub { print "Caught a sigchild $!\n" ;
	waitpid($kidpid, 0);
	$playing=0;
	if ($playing==0){ 
		my $nxt=shift @play_queue;
		my $tnxt=shift @title_queue;
		if (defined ($nxt)){ play_song($nxt);}
		else {$textbox->destroy if Tk::Exists($textbox);}
	}
	make_playinglb();
};

sub play_song {
	(my $song)=@_;
	$playing=1;
	my $txt=$song;
	$nowplaying_file=$song;
	
print "Now playing $nowplaying_file\n";
	$txt=~s/mp3$/txt/;
	if ( -f $txt ){ print "There is a songtext~\n"; }
	make_textbox($song);
	if (!defined($kidpid = fork())) {
		# fork returned undef, so failed
		die "cannot fork: $!";
	} elsif ($kidpid == 0) {
		print "Playing $song\n";
		#exec("/usr/local/bin/monoplay",$song);
		open (STDOUT,'>>','/dev/null');
		open (STDERR,'>>','/dev/null');
		exec('bash', '-c',"mpg123 --mix $song");
		# if the exec fails, fall through to the next statement
		die "can't exec date: $!";
	}
} 


sub queue_song {
	(my $song,my $title)=@_;
	push @play_queue,$song;
	push @title_queue,$title;
	print "Queue $title --- $song\n";
	if ($playing==0){ 
		print "Playing=$playing, so start the next song\n";
		my $nxt=shift @play_queue;
		if (defined ($nxt)){ play_song($nxt);}
	}
	else {
		print "Playing=$playing, so just queue\n";
		make_playinglb();
	}
}

sub queue_album {
	(my $album)=@_;
	$album=$selected_album unless defined $album;
	my $search=$album; $search=~s/'/_/g;
	db_dosql ("SELECT DISTINCT title,file FROM mp3 WHERE album LIKE '$search' GROUP BY track  ORDER BY track");
	while ((my $title,my $file)=db_getrow()){
		queue_song($file,$title);
	}
}

sub queue_10 {
	my $where='WHERE TRUE ';
	if ($selected_artist=~/_ALL_/){}
	elsif (defined($selected_artist)){$where="$where AND artist='$selected_artist'";}
	if ($selected_album=~/_ALL_/){}
	elsif (defined($selected_album)){$where="$where AND album='$selected_album'";}
print "$where\n";
	db_dosql ("SELECT DISTINCT title,file FROM mp3 $where  ORDER BY RANDOM()  LIMIT 10");
	while ((my $title,my $file)=db_getrow()){
		queue_song($file,$title);
	}
}

sub next_song {
	print "Killing $kidpid\n";
	if ($kidpid+1>2){kill 9,$kidpid;}
	else { print "     nothing to kill\n";}
}


		

#                  _                  _           _               
#  _ __ ___   __ _(_)_ __   __      _(_)_ __   __| | _____      __
# | '_ ` _ \ / _` | | '_ \  \ \ /\ / / | '_ \ / _` |/ _ \ \ /\ / /
# | | | | | | (_| | | | | |  \ V  V /| | | | | (_| | (_) \ V  V / 
# |_| |_| |_|\__,_|_|_| |_|   \_/\_/ |_|_| |_|\__,_|\___/ \_/\_/  
#                                                                 

$mw = MainWindow->new;

# Menu bar
sub make_menubar {
	$menu_bar=$mw->Frame(
		-relief		=> 'groove',
		-borderwidth	=> 3,
		) -> pack (
			-side	=>'top',
			-fill	=>'x'
		);
	$menu_file=$menu_bar->Menubutton(
		-text		=> 'File'
		) -> pack ( -side =>'left');
	$menu_file-> command (
		-label	=> 'Rescan MP3s',
		-command=> sub {
			undef @play_queue;
			listmp3();
		}
		);
	$menu_file->separator();
	$menu_file-> command (
		-label	=> 'Exit',
		-command=> sub {
			undef @play_queue;
			next_song();
			system("stty sane");
			exit;
		}
		);
	$menu_file->separator();
}
# top frame set
sub make_topframes {
	$frame_message=$mw->Frame(
		) -> pack (
			-side	=>'top'
		);
	$frame_main=$mw->Frame(
		) -> pack (
			-side	=>'bottom'
		);
}
# list frames

sub make_listframes {
	$frame_artist=$frame_main->Frame(
		) -> pack (
			-side  => 'left'
		);
	$frame_artist->Label (
		-text   => 'Artist',
		-width  => 8
	) -> pack (
		-side => 'top',
	);
	$frame_artist->Label (
		-textvariable => \$selected_artist,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	my $entry;
	$entry=$frame_artist->Entry(
		-textvariable => \$filter_artist,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	$entry->bind('<KeyRelease>' => sub {
		if( length($filter_artist)>1){
			make_artistlb()
		}
	});
	
	$frame_album=$frame_main->Frame(
		) -> pack (
			-side => 'left'
		);
	$frame_album->Label (
		-text   => 'Album',
		-width  => 50
	) -> pack (
		-side => 'top',
	);
	$frame_album->Label (
		-textvariable => \$selected_album,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	$entry=$frame_album->Entry(
		-textvariable => \$filter_album,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	$entry->bind('<KeyRelease>' => sub {
		if(length ($filter_album)>1){
			make_albumlb()
		}
	});
	
	$frame_title=$frame_main->Frame(
		) -> pack (
			-side => 'left'
		);
	$frame_title->Label (
		-text   => 'Title',
		-width  => 50
	) -> pack (
		-side => 'top',
	);
	$frame_title->Label (
		-textvariable => \$selected_title,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	$entry=$frame_title->Entry(
		-textvariable => \$filter_title,
		-width  => 30
	) -> pack (
		-side => 'top',
	);
	$entry->bind('<KeyRelease>' => sub {
		if (length ($filter_title)>1){
			make_titlelb();
		}
	});
	$frame_playlist=$frame_main->Frame(
		) -> pack (
			-side => 'left'
		);
	$frame_actions=$frame_main->Frame(
		) -> pack (
			-side => 'left'
		);
	$frame_text=$frame_main->Frame(
		) -> pack (
			-side => 'left'
		);
	$frame_text->Label (-text=>"Songtext" ,  -width      => 100)->pack(-side=>'top');
}
sub make_buttonframe {
	$frame_inactions->destroy if (Tk::Exists($frame_inactions));
	$frame_inactions=$frame_actions->Frame()->pack();
	$frame_inactions->Label (-textvariable=>$nowplaying_file ,  -width      => 30)->pack(-side=>'top');
	$frame_inactions->Button (
		-text	=> 'Stop current song',
		-width	=> 30,
		-command => sub {
			next_song();
		} )-> pack(
			-side	=> 'top'
		);
	$frame_inactions->Button (
		-text	=> 'Play album',
		-width	=> 30,
		-command => sub {
			queue_album();
		} )-> pack(
			-side	=> 'top'
		);
	$frame_inactions->Button (
		-text	=> 'Play 10 songs',
		-width	=> 30,
		-command => sub {
			queue_10();
		} )-> pack(
			-side	=> 'top'
		);
	$frame_inactions->Button (
		-text	=> 'Clear play queue',
		-width	=> 30,
		-command => sub {
			undef @play_queue;
			undef @title_queue;
			make_playinglb();
		} )-> pack(
			-side	=> 'top'
		);
	
}
# listbox variables
# title listbox
sub make_titlelb {
	$listbox_title->destroy if (Tk::Exists($listbox_title));
	$listbox_title=$frame_title->Scrolled(
		"Listbox",
		-scrollbars => "e",
		-selectmode => "single",
		-height     => 30,
		-width      => 70
	)->pack(-side => 'bottom'  );
	$listbox_title->insert('end','__ALL_TITLES__');
	if (($selected_artist =~ /_ALL_/) && ($selected_album=~/_ALL_ALBUMS__/)){
		db_dosql("SELECT DISTINCT artist,album,title FROM mp3 ORDER BY track,title");
	}
	elsif ($selected_album =~ /_ALL_/) {
		my $search=$selected_artist; $search=~s/'/_/g;
		db_dosql("SELECT DISTINCT artist,album,title FROM mp3 WHERE artist LIKE '$search' ORDER BY artist,track,track,title");
	}
	elsif ($selected_artist =~ /_ALL_/) {
		my $search=$selected_album; $search=~s/'/_/g;
		db_dosql("SELECT DISTINCT artist,album,title FROM mp3 WHERE album LIKE '$search' ORDER BY artist,track,track,title");
	}
	else {
		my $search1=$selected_album; $search1=~s/'/_/g;
		my $search2=$selected_artist; $search2=~s/'/_/g;
		db_dosql("SELECT DISTINCT artist,album,title FROM mp3 WHERE artist LIKE '$search2' AND album LIKE '$search1' ORDER BY artist,track,track,title");
	}
	$listbox_title->insert('end','__ALL_TITLES__');
	my $fltr=$filter_title;
	$fltr='.' unless defined $fltr;
	$fltr='.' if ($fltr eq '');
	while((my $artist,my $album,my $title)=db_getrow()){
		$title=~s/ : / /g;
		$artist=~s/ : / /g;
		$album=~s/ : / /g;

		if ($title=~/$fltr/i){
			$listbox_title->insert('end',"$artist : $album : $title");
		}
	}
	$listbox_title->bind('<Button-1>', sub {
		$selected_title=$listbox_title->get($listbox_title->curselection());
		if ($selected_title=~/(.*) : (.*) : (.*)/){
			$selected_artist=$1;
			$selected_album=$2;
		}
		$selected_title=~s/^.* : //;
		print "$selected_title\n";
		if ($selected_title=~/^__ALL_/){$filter_title='';make_titlelb();}
		else {
			$selected_album='__ALL_ALBUMS__' unless defined $selected_album;
			$selected_artist='__ALL_ARTISTS__' unless defined $selected_artist;
			my $search1=$selected_album; $search1=~s/'/_/g;
			my $search2=$selected_artist; $search2=~s/'/_/g;
			my $search3=$selected_title; $search3=~s/'/_/g;
			
			if (($selected_artist =~/_ALL_/) && ($selected_album=~/_ALL_/)){
				db_dosql("SELECT file FROM mp3 WHERE title LIKE '$search3' GROUP BY title");
			}
			elsif ($selected_artist =~/_ALL_/) {
				db_dosql("SELECT file FROM mp3 WHERE title LIKE '$search3' AND album LIKE '$search1' GROUP BY title");
			}
			elsif ($selected_album=~/_ALL_/){
				db_dosql("SELECT file FROM mp3 WHERE title LIKE '$search3' AND artist LIKE '$search2' GROUP BY title");
			}
			else {
				db_dosql("SELECT file FROM mp3 WHERE title LIKE '$search3' AND album LIKE '$search1' AND artist LIKE '$search2' GROUP BY title");
			}
			while ((my $selfile)=db_getrow()){
				queue_song($selfile,$selected_title);
			}
		}
	} ) ;
}

# album listbox
sub make_albumlb {
	$listbox_album->destroy if (Tk::Exists($listbox_album));
	$listbox_album=$frame_album->Scrolled(
		"Listbox",
		-scrollbars => "e",
		-selectmode => "single",
		-height     => 30,
		-width      => 50
	)->pack(-side => 'bottom'  );
	$listbox_album->insert('end','__ALL_ALBUMS__');
	$listbox_album->insert('end','__NO_ALBUM__');
	if ($selected_artist =~ /_ALL_/){
		db_dosql("SELECT DISTINCT artist,album FROM mp3 ORDER BY  artist,album");
	}
	elsif ($selected_artist =~ /_NO_/){
		db_dosql("SELECT DISTINCT artist,album FROM mp3 ORDER BY artist,album");
	}
	else {
		my $search=$selected_artist; $search=~s/'/_/g;
		db_dosql("SELECT DISTINCT artist, album FROM mp3 WHERE artist LIKE '$search' ORDER BY artist,album");
	}
	my $fltr=$filter_album;
	$fltr='.' unless defined $fltr;
	$fltr='.' if ($fltr eq '');
	
	while((my $artist,my $album)=db_getrow()){
		$artist=~s/ : //g;
		$album=~s/ : //g;
		if ($album=~/$fltr/i){
			$listbox_album->insert('end',"$artist : $album");
		}
	}
	$listbox_album->bind('<Button-1>', sub {
		$selected_album=$listbox_album->get($listbox_album->curselection());
		$selected_album=~s/^.* : //g;
		$selected_album=~s/'/_/g;
		if ($selected_album=~/^__ALL_/){$filter_album='';make_albumlb();}
		my $search=$selected_album; $search=~s/'/_/g;
		db_dosql("SELECT DISTINCT artist FROM mp3 WHERE album LIKE '$search'");
		while ((my $a)=db_getrow()){
			print " $selected_album   by $a \n";
		}
		make_titlelb;
		print "$selected_album\n";
	} ) ;
}

# artists listbox
sub make_artistlb {
	$listbox_artist->destroy if Tk::Exists($listbox_artist);
	$listbox_artist=$frame_artist->Scrolled(
		"Listbox",
		-scrollbars => "e",
		-selectmode => "single",
		-height     => 30,
		-width      => 30
	)->pack(-side => 'bottom'  );
	$listbox_artist->insert('end','__ALL_ARTISTS__');
	$listbox_artist->insert('end','__NO_ARTIST__');
	db_dosql("SELECT DISTINCT artist FROM mp3 ORDER BY artist");
	my $fltr=$filter_artist;
	$fltr='.' unless defined $fltr;
	$fltr='.' if ($fltr eq '');
	while((my $artist)=db_getrow()){
		if ($artist=~/$fltr/i){
			$listbox_artist->insert('end',$artist);
		}
	}
	$listbox_artist->bind('<Button-1>', sub {
		$selected_artist=$listbox_artist->get($listbox_artist->curselection());
		if ($selected_artist=~/_ALL_/){$filter_artist='';make_artistlb();}
		$selected_album='__ALL_ALBUMS__';
		$selected_artist=~s/'/''/g;
		make_albumlb;
		make_titlelb;
		print "$selected_artist\n";
	} ) ;
}

# listbox for the play queue
sub make_playinglb {
	$listbox_playing->destroy if Tk::Exists($listbox_playing);
	$listbox_playing=$frame_inactions->Scrolled(
                "Listbox",
                -scrollbars => "e",
                -selectmode => "single",
                -height     => 10,
                -width      => 30
        )->pack(-side => 'bottom'  );
	for (@title_queue){
		$listbox_playing->insert('end',$_);
	}
}


sub make_textbox {
	(my $file)=@_;
	$file=~s/mp3/txt/;
	print "Make textbox for $file\n";
	$textbox->destroy if Tk::Exists($textbox);
	if (-f $file){
		$textbox=$frame_text->Scrolled('Viewer', -wrap => 'none',  -width      => 100)->pack(-side=>'bottom');
		$textbox->Load($file)
	}
	else {
		$textbox=$frame_text->Label (-text=>"No songtext")->pack(-side=>'bottom');
	}
}
	


$SIG{INT}  = sub { print "Caught a sigINT $!\n" ;system("stty sane");if ($kidpid+1>2){kill 9,$kidpid;}; waitpid($kidpid, 0); $playing=0; exit; };
$SIG{TERM} = sub { print "Caught a sigTERM $!\n";system("stty sane");if ($kidpid+1>2){kill 9,$kidpid;}; waitpid($kidpid, 0); $playing=0; exit; };

$mw->Label ( -text=>' ', -height=>50)->pack(-side =>'left');

make_menubar();
make_topframes();
make_listframes();
make_artistlb();
make_albumlb();
make_titlelb();
make_buttonframe();
make_playinglb();
make_textbox("Nothing__no_file_whatsoever");

MainLoop;

system("stty sane");
