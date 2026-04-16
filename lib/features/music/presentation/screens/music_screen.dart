import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/music/domain/entities/music_track.dart';
import 'package:pareto_lingo/features/music/presentation/providers/music_providers.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    hide PlayerState;

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _linkTitleController = TextEditingController();
  final TextEditingController _linkArtistController = TextEditingController();
  final TextEditingController _linkLyricsController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  String _query = '';
  MusicTrack? _activeTrack;
  _CustomSongRequest? _customSong;
  YoutubePlayerController? _youtubeController;
  PlayerState? _playerState;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _lyricsTrackKey;
  bool _isDownloading = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _tts.awaitSpeakCompletion(true);
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        final shouldClearActiveAudio =
            state.processingState == ProcessingState.completed &&
            (_activeTrack != null ||
                (_customSong != null && !_customSong!.isYouTube));
        if (shouldClearActiveAudio) {
          _activeTrack = null;
          _customSong = null;
          _position = Duration.zero;
        }
      });
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _linkController.dispose();
    _linkTitleController.dispose();
    _linkArtistController.dispose();
    _linkLyricsController.dispose();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _disposeYoutubeController();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => supportedLearningLanguages.first.code,
        );
    final language = languageOptionByCode(languageCode);
    final searchAsync = ref.watch(
      musicSearchProvider((languageCode: languageCode, query: _query)),
    );
    final isAudioPlaying = _playerState?.playing ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('${language.flag} Music & Lyrics')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.7),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _buildHeroCard(context, language.flag),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    setState(() => _query = value.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, or lyrics...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon:
                        _controller.text.isEmpty
                            ? null
                            : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() => _query = _controller.text.trim());
                        },
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('Search Songs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _openCustomSongSheet,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Add Link'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(language.name),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search results are previews. Paste a direct audio or YouTube link to play the source you provide.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              if (_activeTrack != null || _customSong != null)
                _buildNowPlayingPanel(context, isAudioPlaying),
              const SizedBox(height: 12),
              Expanded(
                child: searchAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (_, __) => _buildError(
                        context,
                        'Music search is temporarily unavailable. Try again or search with a different keyword.',
                      ),
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No songs found. Try a different song name, artist, or keep the search empty for language-based suggestions.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack =
                            _activeTrack?.trackId == track.trackId &&
                            _activeTrack?.previewUrl == track.previewUrl;
                        return _SongCard(
                          track: track,
                          isPlaying: isCurrentTrack && isAudioPlaying,
                          isDownloading:
                              _isDownloading &&
                              _lyricsTrackKey == _trackKey(track),
                          onPlay: () => _togglePreview(track),
                          onLyrics:
                              () => _showLyricsSheet(
                                context,
                                title: track.displayTitle,
                                artist: track.displayArtist,
                                genre: track.primaryGenreName,
                                initialLyrics: null,
                                downloadTrack: track,
                              ),
                          onDownload: () => _downloadPreview(context, track),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => setState(() => _query = _controller.text.trim()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingPanel(BuildContext context, bool isAudioPlaying) {
    final customSong = _customSong;
    final track = _activeTrack;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.75),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withOpacity(0.55),
            ],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child:
            customSong != null && customSong.isYouTube
                ? _buildYoutubePanel(context, customSong)
                : _buildAudioPanel(
                  context,
                  title: customSong?.displayTitle ?? track?.displayTitle ?? '',
                  artist:
                      customSong?.displayArtist ?? track?.displayArtist ?? '',
                  genre:
                      customSong?.displayGenre ?? track?.primaryGenreName ?? '',
                  lyrics: customSong?.lyrics ?? '',
                  isPlaying: isAudioPlaying,
                  canDownloadSource:
                      customSong != null && !customSong.isYouTube,
                  onDownloadSource:
                      customSong != null && !customSong.isYouTube
                          ? () => _downloadCustomAudio(context, customSong)
                          : null,
                ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, String flag) {
    final isPlaying = _playerState?.playing ?? false;
    final title = _activeTrack?.displayTitle ?? _customSong?.displayTitle;
    final artist = _activeTrack?.displayArtist ?? _customSong?.displayArtist;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF111827)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$flag Music Room',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title ?? 'Discover, play, and study songs',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  artist ?? 'Choose a song or paste a link',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(
                label: Text(
                  _customSong != null && _customSong!.isYouTube
                      ? 'YouTube'
                      : _activeTrack != null
                      ? 'Audio'
                      : 'Browse',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPlaying ? 'Playing' : 'Stopped',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPanel(
    BuildContext context, {
    required String title,
    required String artist,
    required String genre,
    required String lyrics,
    required bool isPlaying,
    required bool canDownloadSource,
    required VoidCallback? onDownloadSource,
  }) {
    final duration = _duration ?? Duration.zero;
    final position = _position > duration ? duration : _position;
    final maxMillis =
        duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final progress = position.inMilliseconds.clamp(0, maxMillis).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Playing audio' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist.isEmpty
                        ? genre
                        : (genre.isEmpty ? artist : '$artist • $genre'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _stopCurrentPlayback,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: duration.inMilliseconds == 0 ? null : progress / maxMillis,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position)),
            Text(_formatDuration(duration)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _toggleCurrentAudio,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(isPlaying ? 'Pause' : 'Play'),
            ),
            if (canDownloadSource)
              FilledButton.tonalIcon(
                onPressed: onDownloadSource,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download MP3'),
              ),
            OutlinedButton.icon(
              onPressed:
                  title.isEmpty && artist.isEmpty
                      ? null
                      : () => _showLyricsSheet(
                        context,
                        title: title,
                        artist: artist,
                        genre: genre,
                        initialLyrics: lyrics,
                        downloadTrack: null,
                      ),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Lyrics'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYoutubePanel(
    BuildContext context,
    _CustomSongRequest customSong,
  ) {
    final controller = _youtubeController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_display_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customSong.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: _stopCurrentPlayback,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(customSong.displayArtist),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Theme.of(context).colorScheme.primary,
            ),
            builder: (context, player) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  player,
                  const SizedBox(height: 12),
                  if (customSong.lyrics.isNotEmpty)
                    Text(
                      customSong.lyrics,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        () => _showLyricsSheet(
                          context,
                          title: customSong.displayTitle,
                          artist: customSong.displayArtist,
                          genre: customSong.displayGenre,
                          initialLyrics: customSong.lyrics,
                          downloadTrack: null,
                        ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Lyrics'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _togglePreview(MusicTrack track) async {
    try {
      if (_activeTrack?.previewUrl == track.previewUrl && _player.playing) {
        await _player.pause();
        return;
      }

      if (_activeTrack?.previewUrl == track.previewUrl && !_player.playing) {
        _disposeYoutubeController();
        await _player.play();
        return;
      }

      _disposeYoutubeController();
      await _player.stop();
      await _player.setUrl(track.previewUrl);
      await _player.play();
      if (!mounted) return;
      setState(() {
        _activeTrack = track;
        _customSong = null;
        _position = Duration.zero;
        _duration = _player.duration;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play this preview right now.')),
      );
    }
  }

  Future<void> _toggleCurrentAudio() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to control playback right now.')),
      );
    }
  }

  Future<void> _showLyricsSheet(
    BuildContext context, {
    required String title,
    required String artist,
    required String genre,
    required String? initialLyrics,
    required MusicTrack? downloadTrack,
  }) async {
    final service = ref.read(musicServiceProvider);
    final lyrics =
        (initialLyrics ?? '').trim().isNotEmpty
            ? initialLyrics!.trim()
            : await service.fetchLyrics(artist: artist, title: title);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('$artist${genre.isEmpty ? '' : ' • $genre'}'),
                const SizedBox(height: 16),
                if (lyrics.isEmpty)
                  const Text(
                    'Lyrics unavailable for this track.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  )
                else
                  Text(lyrics, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 18),
                if (downloadTrack != null)
                  FilledButton.icon(
                    onPressed:
                        () => _downloadPreview(sheetContext, downloadTrack),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Preview'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCustomSongSheet() async {
    _linkController.text = _customSong?.sourceUrl ?? '';
    _linkTitleController.text = _customSong?.displayTitle ?? '';
    _linkArtistController.text = _customSong?.displayArtist ?? '';
    _linkLyricsController.text = _customSong?.lyrics ?? '';

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.6,
            maxChildSize: 0.98,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Add Song Link',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste a direct MP3/M4A audio link or a public YouTube watch/share link. Search results stay previews; this loads the link you provide.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _linkController,
                    decoration: const InputDecoration(
                      labelText: 'Song link',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _linkTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Song title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _linkArtistController,
                    decoration: const InputDecoration(
                      labelText: 'Artist',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _linkLyricsController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Lyrics or notes',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final request = _buildCustomSongRequest();
                      if (request == null) return;
                      Navigator.of(sheetContext).pop();
                      await _loadCustomSong(request);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Load Link'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  _CustomSongRequest? _buildCustomSongRequest() {
    final sourceUrl = _linkController.text.trim();
    if (sourceUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a song or YouTube link first.')),
      );
      return null;
    }

    return _CustomSongRequest(
      sourceUrl: sourceUrl,
      title: _linkTitleController.text.trim(),
      artist: _linkArtistController.text.trim(),
      lyrics: _linkLyricsController.text.trim(),
      youtubeVideoId: YoutubePlayer.convertUrlToId(sourceUrl),
    );
  }

  Future<void> _loadCustomSong(_CustomSongRequest request) async {
    try {
      final service = ref.read(musicServiceProvider);
      final resolvedLyrics =
          request.lyrics.trim().isNotEmpty
              ? request.lyrics.trim()
              : (request.title.trim().isEmpty && request.artist.trim().isEmpty)
              ? ''
              : await service.fetchLyrics(
                artist: request.artist,
                title: request.title,
              );

      if (request.isYouTube) {
        _disposeYoutubeController();
        await _player.stop();

        final controller = YoutubePlayerController(
          initialVideoId: request.youtubeVideoId!,
          flags: const YoutubePlayerFlags(autoPlay: true, enableCaption: true),
        );

        if (!mounted) {
          controller.dispose();
          return;
        }

        setState(() {
          _customSong = request.copyWith(lyrics: resolvedLyrics);
          _youtubeController = controller;
          _activeTrack = null;
          _position = Duration.zero;
          _duration = null;
        });
        return;
      }

      _disposeYoutubeController();
      await _player.stop();
      await _player.setUrl(request.sourceUrl);
      await _player.play();
      if (!mounted) return;
      setState(() {
        _customSong = request.copyWith(lyrics: resolvedLyrics);
        _activeTrack = null;
        _position = Duration.zero;
        _duration = _player.duration;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load that link. Use a direct MP3/M4A URL or a public YouTube watch/share link.',
          ),
        ),
      );
    }
  }

  Future<void> _downloadCustomAudio(
    BuildContext context,
    _CustomSongRequest request,
  ) async {
    if (request.sourceUrl.trim().isEmpty || request.isYouTube) return;

    final key = 'custom:${request.sourceUrl}';
    setState(() {
      _isDownloading = true;
      _lyricsTrackKey = key;
    });

    try {
      final service = ref.read(musicServiceProvider);
      final file = await service.downloadAudioSource(
        url: request.sourceUrl,
        fileNameHint:
            request.displayTitle == 'Custom song link'
                ? 'custom-audio'
                : '${request.displayArtist} - ${request.displayTitle}',
        fallbackExtension: 'mp3',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            file == null
                ? 'No audio file available to download.'
                : 'Saved MP3/audio to ${file.path}',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Use a direct MP3/M4A audio link.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _lyricsTrackKey = null;
        });
      }
    }
  }

  Future<void> _stopCurrentPlayback() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore stop errors and reset the UI state below.
    }

    _disposeYoutubeController();
    if (!mounted) return;
    setState(() {
      _activeTrack = null;
      _customSong = null;
      _position = Duration.zero;
      _duration = null;
    });
  }

  void _disposeYoutubeController() {
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  Future<void> _downloadPreview(BuildContext context, MusicTrack track) async {
    final service = ref.read(musicServiceProvider);
    final key = _trackKey(track);
    setState(() {
      _isDownloading = true;
      _lyricsTrackKey = key;
    });

    try {
      final file = await service.downloadPreview(track: track);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            file == null
                ? 'No preview available to download.'
                : 'Saved to ${file.path}',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download failed.')));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _lyricsTrackKey = null;
        });
      }
    }
  }

  String _trackKey(MusicTrack track) => '${track.trackId}:${track.trackName}';
}

class _CustomSongRequest {
  final String sourceUrl;
  final String title;
  final String artist;
  final String lyrics;
  final String? youtubeVideoId;

  const _CustomSongRequest({
    required this.sourceUrl,
    required this.title,
    required this.artist,
    required this.lyrics,
    required this.youtubeVideoId,
  });

  bool get isYouTube => youtubeVideoId != null && youtubeVideoId!.isNotEmpty;

  String get displayTitle => title.isEmpty ? 'Custom song link' : title;

  String get displayArtist => artist.isEmpty ? 'User supplied link' : artist;

  String get displayGenre => isYouTube ? 'YouTube' : 'Direct audio';

  _CustomSongRequest copyWith({String? lyrics}) {
    return _CustomSongRequest(
      sourceUrl: sourceUrl,
      title: title,
      artist: artist,
      lyrics: lyrics ?? this.lyrics,
      youtubeVideoId: youtubeVideoId,
    );
  }
}

class _SongCard extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isDownloading;
  final VoidCallback onPlay;
  final VoidCallback onLyrics;
  final VoidCallback onDownload;

  const _SongCard({
    required this.track,
    required this.isPlaying,
    required this.isDownloading,
    required this.onPlay,
    required this.onLyrics,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.75),
          ],
        ),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 82,
                height: 82,
                child:
                    track.artworkUrl.isNotEmpty
                        ? Image.network(track.artworkUrl, fit: BoxFit.cover)
                        : ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.music_note_rounded,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.displayAlbum,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(isPlaying ? 'Pause' : 'Play'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onLyrics,
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Lyrics'),
                      ),
                      OutlinedButton.icon(
                        onPressed: isDownloading ? null : onDownload,
                        icon:
                            isDownloading
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.download_rounded),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
