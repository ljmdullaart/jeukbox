window.selectedArtist = null;
window.selectedAlbum = null;
window.selectedTitle = null;
let allArtists = [];
let allAlbums = [];


document.addEventListener('DOMContentLoaded', () => {
  const artistSelect = document.getElementById('artist-select');
  const albumSelect = document.getElementById('album-select');
  const titleSelect = document.getElementById('title-select');
  const playlistSelect = document.getElementById('playlist-select');
  const playlistList = document.getElementById('playlist-list');
  const audioPlayer = document.getElementById('audio-player');

  const artistNameDisplay = document.getElementById('artist-name');
  const albumNameDisplay = document.getElementById('album-name');
  const titleNameDisplay = document.getElementById('title-name');

  const clearArtistButton = document.getElementById('clear-artist');
  const clearAlbumButton = document.getElementById('clear-album');
  const clearTitleButton = document.getElementById('clear-title');
  const clearPlaylistButton = document.getElementById('clear-playlist');
  const playAlbumButton = document.getElementById('play-album');
  const savePlaylistButton = document.getElementById('save-playlist');
  const nextTrackButton = document.getElementById('next-track');
  const artistFilter = document.getElementById('artist-filter');
  const albumFilter = document.getElementById('album-filter');

document.addEventListener('keydown', (event) => {
  const key = event.key.toLowerCase();
  const ctrl = event.ctrlKey;
  const alt = event.altKey;

  // Play next track: N
  if (key === 'n') {
    nextTrackButton.click();
  }

  // Clear playlist: C
  if (key === 'c' && ctrl) {
    clearPlaylistButton.click();
  }

  // Save playlist: S
  if (key === 's' && ctrl) {
    event.preventDefault(); // prevent browser's Save Page dialog
    savePlaylistButton.click();
  }

  // Focus artist search: A
  if (key === 'a' && alt) {
    artistFilter?.focus();
  }

  // Focus album search: L (for "album lister")
  if (key === 'l' && alt) {
    albumFilter?.focus();
  }

  // Focus title select: T
  if (key === 't' && alt) {
    titleSelect?.focus();
  }
});


albumFilter.addEventListener('input', () => {
  const search = albumFilter.value.trim();
  renderAlbumList(search);
});


artistFilter.addEventListener('input', () => {
  const search = artistFilter.value.trim();
  renderArtistList(search);
});


  loadArtists();
  loadAlbums();
  loadTitles();
  loadOfflinePlaylists();




  artistSelect.addEventListener('change', async () => {
    const selected = artistSelect.value || null;
    window.selectedArtist = selected;
    artistNameDisplay.textContent = selected || 'None';

    await loadAlbums(selected);
    albumSelect.selectedIndex = -1;
    window.selectedAlbum = null;
    albumNameDisplay.textContent = 'None';

    await loadTitles(selected, '');
    titleSelect.selectedIndex = -1;
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
  });

  clearArtistButton.addEventListener('click', () => {
    artistSelect.selectedIndex = -1;
    window.selectedArtist = null;
    artistNameDisplay.textContent = 'None';

    albumSelect.innerHTML = '';
    window.selectedAlbum = null;
    albumNameDisplay.textContent = 'None';
    loadAlbums();

    titleSelect.innerHTML = '';
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
    loadTitles();
  });

  albumSelect.addEventListener('change', () => {
    const selected = albumSelect.value || null;
    window.selectedAlbum = selected;
    albumNameDisplay.textContent = selected || 'None';

    titleSelect.innerHTML = '';
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
    loadTitles(window.selectedArtist, selected);
  });

  clearAlbumButton.addEventListener('click', () => {
    albumSelect.selectedIndex = -1;
    window.selectedAlbum = null;
    albumNameDisplay.textContent = 'None';

    titleSelect.innerHTML = '';
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
    loadTitles(window.selectedArtist, '');
  });

  titleSelect.addEventListener('change', async () => {
    const selected = titleSelect.value || null;
    window.selectedTitle = selected;
    titleNameDisplay.textContent = selected || 'None';

    let artist = window.selectedArtist || 'Unknown Artist';
    let album = window.selectedAlbum;
if ((!artist || artist === 'Unknown Artist') && album) {
  try {
    const response = await fetch(`/api/artistfromalbum?album=${encodeURIComponent(album)}`);
    const data = await response.json();
    if (data.artist) {
      artist = data.artist;
    }
  } catch (err) {
    // keep artist as 'Unknown Artist'
  }
}

    if (!album && selected) {
      try {
        const response = await fetch(`/api/album?artist=${encodeURIComponent(artist)}&title=${encodeURIComponent(selected)}`);
        const albums = await response.json();
        if (Array.isArray(albums)) {
          album = albums.find(a => a.album && a.album.trim() !== '')?.album || 'Unknown Album';
        }
      } catch (err) {
        album = 'Unknown Album';
      }
    }

    album = album || 'Unknown Album';
    const display = `${artist}: ${album}: ${selected}`;

    if (selected && !playlistHas(display)) {
      const option = document.createElement('option');
      option.value = display;
      option.textContent = display;
      playlistSelect.appendChild(option);
      playNextInPlaylist();
    }
  });

  clearTitleButton.addEventListener('click', () => {
    titleSelect.selectedIndex = -1;
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
  });

  clearPlaylistButton.addEventListener('click', () => {
    playlistSelect.innerHTML = '';
    audioPlayer.pause();
    audioPlayer.src = '';
  });

  playAlbumButton.addEventListener('click', async () => {
    const artist = window.selectedArtist || '';
    const album = window.selectedAlbum || '';
    if (!album) return;

    try {
      const response = await fetch(`/api/titles?artist=${encodeURIComponent(artist)}&album=${encodeURIComponent(album)}`);
      const titles = await response.json();

      titles.forEach(entry => {
        const display = `${artist || ' '}: ${album || ' '}: ${entry.title}`;
        if (!playlistHas(display)) {
          const option = document.createElement('option');
          option.value = display;
          option.textContent = display;
          playlistSelect.appendChild(option);
        }
      });

      playNextInPlaylist();
    } catch (err) {
      // handle error silently
    }
  });

  audioPlayer.addEventListener('ended', () => {
    if (playlistSelect.options.length > 0) {
      playlistSelect.remove(0);
    }
    playNextInPlaylist();
  });

  function playlistHas(entryText) {
    return Array.from(playlistSelect.options).some(opt => opt.value === entryText);
  }

  function parseEntry(entryText) {
    const [artist, album, ...rest] = entryText.split(':');
    const title = rest.join(':').trim();
    return {
      artist: artist?.trim() || '',
      album: album?.trim() || '',
      title: title || '',
    };
  }

  function playNextInPlaylist() {
    if (playlistSelect.options.length === 0) return;

    const entryText = playlistSelect.options[0].value;
    const { artist, album, title } = parseEntry(entryText);
    const url = `/play?artist=${encodeURIComponent(artist)}&album=${encodeURIComponent(album)}&title=${encodeURIComponent(title)}`;

    audioPlayer.src = url;
    audioPlayer.play().catch(() => {
      playlistSelect.remove(0);
      playNextInPlaylist();
    });
  }

  async function loadOfflinePlaylists() {
    try {
      const response = await fetch('/api/playlists');
      const lists = await response.json();
      playlistList.innerHTML = '';

      lists.forEach(name => {
        const option = document.createElement('option');
        option.textContent = name;
        option.value = name;
        playlistList.appendChild(option);
      });
    } catch (err) {
      // handle error silently
    }
  }

//  async function loadArtists() {
//    try {
//      const response = await fetch('/api/artists');
//      const data = await response.json();
//      artistSelect.innerHTML = '';
//      data.forEach(entry => {
//        const option = document.createElement('option');
//        option.value = entry.artist;
//        option.textContent = entry.artist;
//        artistSelect.appendChild(option);
//      });
//    } catch (err) {
//      // handle error silently
//    }
//  }
async function loadArtists() {
  try {
    const response = await fetch('/api/artists');
    const data = await response.json();
    allArtists = data.map(entry => entry.artist);
    renderArtistList('');
  } catch (err) {}
}

function renderArtistList(filter) {
  const filtered = allArtists.filter(name =>
    name.toLowerCase().includes(filter.toLowerCase())
  );

  artistSelect.innerHTML = '';
  filtered.forEach(name => {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = name;
    artistSelect.appendChild(option);
  });
}

function renderAlbumList(filter) {
  const filtered = allAlbums.filter(name =>
    typeof name === 'string' && name.toLowerCase().includes(filter.toLowerCase())
  );

  albumSelect.innerHTML = '';
  filtered.forEach(name => {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = name;
    albumSelect.appendChild(option);
  });
}



  //async function loadAlbums(artist = '') {
    //try {
      //const response = await fetch(`/api/albums?artist=${encodeURIComponent(artist)}`);
      //const data = await response.json();
      //albumSelect.innerHTML = '';
      //data.forEach(entry => {
        //const option = document.createElement('option');
        //option.value = entry.album;
        //option.textContent = entry.album;
        //albumSelect.appendChild(option);
      //});
    //} catch (err) {
      //// handle error silently
    //}
  //}

async function loadAlbums(artist = '') {
  try {
    const response = await fetch(`/api/albums?artist=${encodeURIComponent(artist)}`);
    const data = await response.json();
    allAlbums = data.map(entry => entry.album || '');  // <— extract string only
    renderAlbumList('');
  } catch (err) {}
}


  async function loadTitles(artist = '', album = '') {
    try {
      const response = await fetch(`/api/titles?artist=${encodeURIComponent(artist)}&album=${encodeURIComponent(album)}`);
      const data = await response.json();
      titleSelect.innerHTML = '';
      data.forEach(entry => {
        const option = document.createElement('option');
        option.value = entry.title;
        option.textContent = entry.title;
        titleSelect.appendChild(option);
      });
    } catch (err) {
      // handle error silently
    }
  }
playlistList.addEventListener('change', async () => {
  const selected = playlistList.value;
  if (!selected) return;

  try {
    const response = await fetch(`/api/playcontent?name=${encodeURIComponent(selected)}`);
    const tracks = await response.json();

    tracks.forEach(({ artist, album, title }) => {
      const display = `${artist || 'Unknown Artist'}: ${album || 'Unknown Album'}: ${title}`;
      if (!playlistHas(display)) {
        const option = document.createElement('option');
        option.value = display;
        option.textContent = display;
        playlistSelect.appendChild(option);
      }
    });

    playNextInPlaylist();
  } catch (err) {
    // Handle silently
  }
});

savePlaylistButton.addEventListener('click', () => {
  if (playlistSelect.options.length === 0) return;

  const lines = ['#PLAYLIST My Saved Playlist'];
  for (const option of playlistSelect.options) {
    const { artist, album, title } = parseEntry(option.value);
    lines.push(`${artist}\t${album}\t${title}`);
  }

  const blob = new Blob([lines.join('\n') + '\n'], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);

  const a = document.createElement('a');
  a.href = url;
  a.download = 'saved_playlist.txt';
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);

  URL.revokeObjectURL(url);
});

nextTrackButton.addEventListener('click', () => {
  audioPlayer.pause();
  audioPlayer.currentTime = 0;

  if (playlistSelect.options.length > 0) {
    playlistSelect.remove(0);
    playNextInPlaylist();
  }
});


});
