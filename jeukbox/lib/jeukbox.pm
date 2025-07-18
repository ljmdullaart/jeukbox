package jeukbox;
use Dancer2;
use Dancer2::Plugin::OpenAPI;

use HTTP::Date 'time2str';
use File::Spec;
use File::Slurp 'read_file';

use database qw(get_artists);
use database qw(get_albums);
use database qw(get_album);
use database qw(get_titles);
use database qw(get_file);
use database qw(get_txt);
use database qw(get_artists_from_song);
use database qw(get_artists_from_album);


our $VERSION = '0.1';

get '/' => sub {
	my $ua = request->header('User-Agent') // '';	
	if ($ua =~ /Mobile|Android|iPhone|iPad/i) {
		content_type 'text/html'; 
		template 'index_mobile' => { 'title' => 'jeukbox' };
	}
	else {
		content_type 'text/html'; 
		template 'index' => { 'title' => 'jeukbox' };
	}
};


#     _    ____ ___ 
#    / \  |  _ \_ _|
#   / _ \ | |_) | | 
#  / ___ \|  __/| | 
# /_/   \_\_|  |___|
#                

get '/api/artists' => sub {
	content_type 'application/json';
	get_artists('json');
};

get '/api/artistfromalbum' => sub {
	my $album = query_parameters->get('album');
	content_type 'application/json';
	get_artists_from_album('json',$album);
};
	
	

get '/api/albums' => sub {
	my $artist = query_parameters->get('artist');
	content_type 'application/json';
	get_albums("$artist",'json');

};

get '/api/artistsfromsong' => sub {
	my $song = query_parameters->get('song');
	content_type 'application/json';
	get_artists_from_song('json',"$song");

};

get '/api/titles' => sub {
	my $artist = query_parameters->get('artist');
	my $album = query_parameters->get('album');
	$album='' unless defined $album;
	$artist='' unless defined $artist;
	content_type 'application/json';
	get_titles ("$artist","$album",'json');
};

get '/api/file' => sub {
	my $artist = query_parameters->get('artist');
	my $album = query_parameters->get('album');
	my $title = query_parameters->get('title');
	$album='' unless defined $album;
	$artist='' unless defined $artist;
	$title='' unless defined $title;
	get_file ("$artist","$album","$title");
};

get '/api/album' => sub {
	my $artist = query_parameters->get('artist');
	my $title = query_parameters->get('title');
	$artist='' unless defined $artist;
	$title='' unless defined $title;
	get_album ("$artist","$title");
};

	
get '/play' => sub {
    my $artist = query_parameters->get('artist') // '';
    my $album  = query_parameters->get('album')  // '';
    my $title  = query_parameters->get('title')  // '';

    my $filename = get_file($artist, $album, $title);
    unless ($filename && -e $filename) {
        status 'not_found';
        warn "Audio file $filename  not found." if defined $filename;
        warn "Audio file undefined" unless defined $filename;
        return { error => "Audio file not found."};
     
    }

    my $size = -s $filename;
	warn "Attempting to send file: $filename\n";

    send_file(
        $filename,
        content_type => 'audio/mpeg',
	system_path => 1,
        content_disposition => 'inline',
        headers => [
            'Content-Length' => $size,
            'Last-Modified'  => time2str((stat($filename))[9]),
        ],
    );
};
get '/txt' => sub {
    my $artist = query_parameters->get('artist') // '';
    my $album  = query_parameters->get('album')  // '';
    my $title  = query_parameters->get('title')  // '';

    my $filename = get_txt($artist, $album, $title);
    warn "Getting $filename...";
    unless ($filename && -e $filename) {
        status 'not_found';
        return { error =>"No Lyrics"};
    }

    my $size = -s $filename;
	print STDERR "Attempting to send file: $filename\n";

    send_file(
        $filename,
        content_type => 'text/plain',
	system_path => 1,
        content_disposition => 'inline',
        headers => [
            'Content-Length' => $size,
            'Last-Modified'  => time2str((stat($filename))[9]),
        ],
    );
};


get '/api/playlists' => sub {
    my @search_dirs = ('.', '..', '../..', '/links');
    my @playlists;

    for my $dir (@search_dirs) {
        my $playlist_dir = File::Spec->catdir($dir, 'playlists');
        next unless -d $playlist_dir;

        opendir my $dh, $playlist_dir or next;
        for my $file (readdir $dh) {
            next if $file =~ /^\./;  # skip dotfiles
            my $path = File::Spec->catfile($playlist_dir, $file);
            next unless -f $path;

            my $first_line = (read_file($path, err_mode => 'quiet'))[0];
            if ($first_line && $first_line =~ /^#PLAYLIST\s+(.+)/) {
                push @playlists, $1;
            }
        }
        closedir $dh;
    }

    return to_json(\@playlists);
};

get '/api/playcontent' => sub {
    my $target_name = query_parameters->get('name') // '';
    return to_json([]) unless $target_name;

    my @search_dirs = ('.', '..', '../..', '/links');
    for my $dir (@search_dirs) {
        my $playlist_dir = File::Spec->catdir($dir, 'playlists');
        next unless -d $playlist_dir;

        opendir my $dh, $playlist_dir or next;
        for my $file (readdir $dh) {
            next if $file =~ /^\./;  # skip dotfiles
            my $path = File::Spec->catfile($playlist_dir, $file);
            next unless -f $path;

            my @lines = read_file($path, err_mode => 'quiet');
            next unless @lines;

            if ($lines[0] =~ /^#PLAYLIST\s+(.+)/) {
                my $found_name = $1;
                if ($found_name eq $target_name) {
                    my @tracks;
                    for my $line (@lines[1..$#lines]) {
                        chomp($line);
                        my ($artist, $album, $title) = split /\t/, $line;
                        push @tracks, {
                            artist => $artist // '',
                            album  => $album  // '',
                            title  => $title  // '',
                        } if defined $title;
                    }
                    closedir $dh;
                    return to_json(\@tracks);
                }
            }
        }
        closedir $dh;
    }

    return to_json([]);
};

true;
