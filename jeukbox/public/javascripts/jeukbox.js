window.selectedArtist = null;
window.selectedAlbum = null;
window.selectedTitle = null;
let allArtists = [];
let allAlbums = [];
let allTitles = [];



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
  const shuffleButton = document.getElementById('shuffle-playlist');
  const artistFilter = document.getElementById('artist-filter');
  const albumFilter = document.getElementById('album-filter');
  const jukeboxVisual = document.getElementById('jukebox-visual');


document.addEventListener('keydown', (event) => {
  const key = event.key.toLowerCase();
  const ctrl = event.ctrlKey;
  const alt = event.altKey;
  const shift = event.shiftKey;

  // Play next track: N
  if (key === 'n' && alt) {
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

  if (key === 'a' && alt ) {
    const selectElement = document.getElementById('artist-select');
    if (selectElement) {
      selectElement.focus();
    }
  }
  if (key === 'b' && alt ) {
    const selectElement = document.getElementById('album-select');
    if (selectElement) {
      selectElement.focus();
    }
  }
  if (key === 'c' && alt ) {
    const selectElement = document.getElementById('title-select');
    if (selectElement) {
      selectElement.focus();
    }
  }
  if (key === 'd' && alt && shift) {
    const selectElement = document.getElementById('playlist-list');
    if (selectElement) {
      selectElement.focus();
    }
  }
  if (key === 'e' && alt && shift) {
    const selectElement = document.getElementById('lyrics-box');
    if (selectElement) {
      selectElement.focus();
    }
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

  titleSelect.addEventListener('click', async () => { await handleTitleSelect(); } ) ;
  titleSelect.addEventListener('keydown', async (event) => { if (event.key === 'Enter') {await handleTitleSelect();}}) ;
  async function handleTitleSelect(){
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
  };

  clearTitleButton.addEventListener('click', () => {
    titleSelect.selectedIndex = -1;
    window.selectedTitle = null;
    titleNameDisplay.textContent = 'None';
  });

  clearPlaylistButton.addEventListener('click', () => {
    playlistSelect.innerHTML = '';
    audioPlayer.pause();
    audioPlayer.src = '';
    const lyricsBox = document.getElementById('lyrics-box');
    if (lyricsBox) {
      lyricsBox.textContent = '';
    }
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
    if (!audioPlayer.paused && !audioPlayer.ended) return;

    const entryText = playlistSelect.options[0].value;
    const { artist, album, title } = parseEntry(entryText);
    const url = `/play?artist=${encodeURIComponent(artist)}&album=${encodeURIComponent(album)}&title=${encodeURIComponent(title)}`;

    audioPlayer.src = url;
    audioPlayer.play().catch(() => {
      playlistSelect.remove(0);
      playNextInPlaylist();
    });
    loadLyrics(title, artist, album);

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
    allTitles = data.map(entry => entry.title || '');
    renderTitleList('');
  } catch (err) {
    allTitles = [];
    renderTitleList('');
  }
}
function renderTitleList(filter) {
  const filtered = allTitles.filter(name =>
    typeof name === 'string' && name.toLowerCase().includes(filter.toLowerCase())
  );

  titleSelect.innerHTML = '';
  filtered.forEach(name => {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = name;
    titleSelect.appendChild(option);
  });
    titleSelect.selectedIndex = -1;

}

const titleFilter = document.getElementById('title-filter');

titleFilter.addEventListener('input', () => {
  const search = titleFilter.value.trim();
  renderTitleList(search);
});


  playlistList.addEventListener('click', async () => { await handlePlaylistList(); } ) ;
  playlistList.addEventListener('keydown', async (event) => { if (event.key === 'Enter') {await handlePlaylistList();}}) ;
  async function handlePlaylistList(){
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
};

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

audioPlayer.addEventListener('play', () => {
  jukeboxVisual.src = 'images/jeukbox.gif';
});

audioPlayer.addEventListener('pause', () => {
  jukeboxVisual.src = 'images/jeukboxstatic.jpg';
});

audioPlayer.addEventListener('ended', () => {
  jukeboxVisual.src = 'images/jeukboxstatic.jpg';
  const lyricsBox = document.getElementById('lyrics-box');
  if (lyricsBox) {
    lyricsBox.textContent = '';
  }
});
audioPlayer.addEventListener('error', () => {
  jukeboxVisual.src = 'images/jeukboxstatic.jpg';
});

async function loadLyrics(title, artist, album) {
  const lyricsBox = document.getElementById('lyrics-box');
  lyricsBox.textContent = 'Loading lyrics...';

  try {
    const response = await fetch(`/txt?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(artist)}&album=${encodeURIComponent(album)}`);
    if (!response.ok) throw new Error('Lyrics not found');
    const text = await response.text();
    lyricsBox.textContent = text || 'No lyrics available for this track.';
  } catch (err) {
    lyricsBox.textContent = 'Lyrics not available.';
  }
}


shuffleButton.addEventListener('click', () => {
  const children = Array.from(playlistSelect.children);

  if (children.length <= 1) return; // nothing to shuffle

  const nowPlaying = children[0]; // song currently playing
  const rest = children.slice(1); // songs waiting in queue

  // Fisher-Yates shuffle
  for (let i = rest.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [rest[i], rest[j]] = [rest[j], rest[i]];
  }

  // Clear and rebuild playlist
  playlistSelect.innerHTML = '';
  playlistSelect.appendChild(nowPlaying); // keep current first
  rest.forEach(el => playlistSelect.appendChild(el));
});
document.addEventListener('keydown', function(event) {
  // Ignore keypresses inside input or textarea fields
  const tag = event.target.tagName.toLowerCase();
  if (tag === 'input' || tag === 'textarea') return;

  const audio = document.getElementById('audio-player');

  // Use spacebar to toggle play/pause
  if (event.code === 'Space') {
    event.preventDefault(); // Prevent page scroll
    if (audio.paused) {
      audio.play();
    } else {
      audio.pause();
    }
  }
});


});
