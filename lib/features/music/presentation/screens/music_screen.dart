import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/music/domain/entities/music_track.dart';
import 'package:pareto_lingo/features/music/presentation/providers/music_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    hide PlayerState;

// ─── Neobrutalism Design Tokens ────────────────────────────────────────────╮
const _kBorder = BorderSide(color: Colors.black, width: 2.5);
const _kBorderRadius = BorderRadius.all(Radius.circular(12));
const _kShadow = [BoxShadow(offset: Offset(4, 4), color: Colors.black)];
const _kAccent = Color(0xFF7DF9FF); // cyan – matches flashcard
const _kAccentYellow = Color(0xFFFFE566);
const _kBg = Color(0xFFF5F5F0); // off-white
// ──────────────────────────────────────────────────────────────────────────╯

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _linkTitleController = TextEditingController();
  final TextEditingController _linkArtistController = TextEditingController();
  final TextEditingController _linkLyricsController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String> _searchText = ValueNotifier<String>('');

  String _query = '';
  MusicTrack? _activeTrack;
  _CustomSongRequest? _customSong;
  YoutubePlayerController? _youtubeController;

  /// Optimistic playing state — changed BEFORE async calls so UI is instant.
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExtractingAudio =
      false; // true while cobalt audio extraction is running
  String? _lyricsTrackKey;
  bool _isDownloading = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _tts.awaitSpeakCompletion(true);
    _controller.addListener(() {
      _searchText.value = _controller.text;
    });

    // Stream listener syncs state with actual player (handles completion etc.)
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final bool actuallyPlaying =
          state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;

      final bool completed = state.processingState == ProcessingState.completed;

      setState(() {
        _isPlaying = actuallyPlaying;
        _isLoading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        if (completed) {
          _activeTrack = null;
          _customSong = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _controller.dispose();
    _linkController.dispose();
    _linkTitleController.dispose();
    _linkArtistController.dispose();
    _linkLyricsController.dispose();
    _searchText.dispose();
    _playerStateSubscription?.cancel();
    _disposeYoutubeController();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────╮
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

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ──────────────────────────────────────────────
            _buildHeader(language.flag, language.name),
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildSearchBar(),
            ),
            // ── Action row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildActionRow(),
            ),
            // ── Now Playing strip ────────────────────────────────────────
            if (_isExtractingAudio)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildExtractionBanner(),
              )
            else if (_activeTrack != null || _customSong != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildNowPlayingPanel(language.name),
              ),
            const SizedBox(height: 10),
            // ── Song list ────────────────────────────────────────────────
            Expanded(
              child: searchAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildError(),
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.music_off_rounded,
                              size: 48,
                              color: Colors.black38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No songs found.\nTry searching by name, artist, or leave blank for suggestions.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    cacheExtent: 1200,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrent = _activeTrack?.trackId == track.trackId;
                      return RepaintBoundary(
                        child: _SongCard(
                          key: ValueKey(_trackKey(track)),
                          track: track,
                          isPlaying: isCurrent && _isPlaying,
                          isLoading: isCurrent && _isLoading,
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
                          onOpenFullSong: () => _openFullSong(track),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────╮

  Widget _buildHeader(String flag, String langName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kAccent,
        border: const Border(bottom: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: _kAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$flag Music Room',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Discover · Play · Study $langName songs',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (_isPlaying) _WaveformWidget(controller: _waveController),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<String>(
      valueListenable: _searchText,
      builder: (context, text, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: _kBorderRadius,
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: _kShadow,
          ),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search songs, artists…',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.black),
              suffixIcon:
                  text.isEmpty
                      ? null
                      : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NeuBrutButton(
                color: Colors.black,
                label: 'Search Songs',
                icon: Icons.travel_explore_rounded,
                textColor: Colors.white,
                onPressed:
                    () => setState(() => _query = _controller.text.trim()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NeuBrutButton(
                color: _kAccentYellow,
                label: 'Add Link',
                icon: Icons.link_rounded,
                onPressed: _openCustomSongSheet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NeuBrutButton(
                color: const Color(0xFFFFB36B),
                label: 'Import File',
                icon: Icons.audio_file_rounded,
                onPressed: _importLocalAudio,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtractionBanner() {
    return Container(
      decoration: BoxDecoration(
        color: _kAccentYellow,
        borderRadius: _kBorderRadius,
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: _kShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Extracting audio from YouTube... this can take a few seconds.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _stopCurrentPlayback,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingPanel(String langName) {
    final customSong = _customSong;
    final track = _activeTrack;

    if (customSong != null && customSong.isYouTube) {
      return _buildYoutubePanel(customSong);
    }

    final title = customSong?.displayTitle ?? track?.displayTitle ?? '';
    final artist = customSong?.displayArtist ?? track?.displayArtist ?? '';
    final genre = customSong?.displayGenre ?? track?.primaryGenreName ?? '';
    final lyrics = customSong?.lyrics ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _kAccent,
        borderRadius: _kBorderRadius,
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: _kShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Album art placeholder
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    track?.artworkUrl.isNotEmpty == true
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            track!.artworkUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 116,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: _kAccent,
                                  size: 28,
                                ),
                          ),
                        )
                        : const Icon(
                          Icons.graphic_eq_rounded,
                          color: _kAccent,
                          size: 28,
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Now Playing' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      artist.isEmpty ? langName : artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Play/Pause button — responds INSTANTLY (optimistic)
              GestureDetector(
                onTap: _toggleCurrentAudio,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      _isLoading
                          ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: _kAccent,
                              strokeWidth: 2.5,
                            ),
                          )
                          : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: _kAccent,
                          ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _stopCurrentPlayback,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          _AudioProgressStrip(player: _player, isPlaying: _isPlaying),
          const SizedBox(height: 10),
          // Bottom action row
          Row(
            children: [
              _NeuBrutButton(
                compact: true,
                color: Colors.black,
                textColor: Colors.white,
                label: 'Lyrics',
                icon: Icons.menu_book_rounded,
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
              ),
              if (track != null) ...[
                const SizedBox(width: 10),
                _NeuBrutButton(
                  compact: true,
                  color: _kAccentYellow,
                  label: 'Full Song',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => _openFullSong(track),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYoutubePanel(_CustomSongRequest customSong) {
    final controller = _youtubeController;
    if (controller == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _kBorderRadius,
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: _kShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_display_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customSong.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              GestureDetector(
                onTap: _stopCurrentPlayback,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.black,
              ),
              builder: (context, player) => player,
            ),
          ),
          if (customSong.lyrics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              customSong.lyrics,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          _NeuBrutButton(
            compact: true,
            color: _kAccentYellow,
            label: 'Lyrics',
            icon: Icons.menu_book_rounded,
            onPressed:
                () => _showLyricsSheet(
                  context,
                  title: customSong.displayTitle,
                  artist: customSong.displayArtist,
                  genre: customSong.displayGenre,
                  initialLyrics: customSong.lyrics,
                  downloadTrack: null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Music search unavailable.\nTry a different keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _NeuBrutButton(
              compact: true,
              color: _kAccent,
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() => _query = _controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Playback ─────────────────────────────────────────────────────────╮

  Future<void> _togglePreview(MusicTrack track) async {
    // Same track → just toggle pause/resume
    if (_activeTrack?.trackId == track.trackId) {
      // Optimistic: flip _isPlaying IMMEDIATELY so UI updates instantly
      setState(() => _isPlaying = !_isPlaying);
      try {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
      } catch (_) {
        if (mounted) setState(() => _isPlaying = _player.playing);
      }
      return;
    }

    // New track — optimistic: show it as loading/playing immediately
    _disposeYoutubeController();
    setState(() {
      _activeTrack = track;
      _customSong = null;
      _isPlaying = true;
      _isLoading = true;
    });

    try {
      await _player.stop();
      await _player.setUrl(track.previewUrl);
      await _player.play();
      // Stream listener will update _isLoading to false when buffering done
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeTrack = null;
        _isPlaying = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play this preview.')),
      );
    }
  }

  Future<void> _toggleCurrentAudio() async {
    if (_isLoading) return;
    // Optimistic flip
    setState(() => _isPlaying = !_isPlaying);
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) setState(() => _isPlaying = _player.playing);
    }
  }

  Future<void> _stopCurrentPlayback() async {
    try {
      await _player.stop();
    } catch (_) {}
    _disposeYoutubeController();
    if (!mounted) return;
    setState(() {
      _activeTrack = null;
      _customSong = null;
      _isPlaying = false;
      _isLoading = false;
      _isExtractingAudio = false;
    });
  }

  void _disposeYoutubeController() {
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  // ─── Lyrics sheet ────────────────────────────────────────────────────╮

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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: _kBorder, left: _kBorder, right: _kBorder),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$artist${genre.isEmpty ? '' : '  •  $genre'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const Divider(height: 24, thickness: 2, color: Colors.black),
                  if (lyrics.isEmpty)
                    const Text(
                      'Lyrics unavailable for this track.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    )
                  else
                    Text(
                      lyrics,
                      style: const TextStyle(fontSize: 15, height: 1.65),
                    ),
                  const SizedBox(height: 24),
                  if (downloadTrack != null)
                    _NeuBrutButton(
                      color: _kAccentYellow,
                      label: 'Download Preview',
                      icon: Icons.download_rounded,
                      onPressed:
                          () => _downloadPreview(sheetContext, downloadTrack),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ─── Custom song sheet ───────────────────────────────────────────────╮

  Future<void> _openCustomSongSheet() async {
    _linkController.text = _customSong?.sourceUrl ?? '';
    _linkTitleController.text = _customSong?.displayTitle ?? '';
    _linkArtistController.text = _customSong?.displayArtist ?? '';
    _linkLyricsController.text = _customSong?.lyrics ?? '';

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: _kBorder, left: _kBorder, right: _kBorder),
            ),
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
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Add Song Link',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste a direct MP3/M4A audio URL or a YouTube watch/share link.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    _neuTextField(_linkController, 'Song link', 'https://…'),
                    const SizedBox(height: 12),
                    _neuTextField(
                      _linkTitleController,
                      'Song title (optional)',
                      '',
                    ),
                    const SizedBox(height: 12),
                    _neuTextField(
                      _linkArtistController,
                      'Artist (optional)',
                      '',
                    ),
                    const SizedBox(height: 12),
                    _neuTextField(
                      _linkLyricsController,
                      'Lyrics / notes (optional)',
                      '',
                      minLines: 4,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 20),
                    _NeuBrutButton(
                      color: Colors.black,
                      textColor: Colors.white,
                      label: 'Load Link',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () async {
                        final request = _buildCustomSongRequest();
                        if (request == null) return;
                        Navigator.of(sheetContext).pop();
                        await _loadCustomSong(request);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _neuTextField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _kBorderRadius,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
      ),
      child: TextField(
        controller: ctrl,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
      ),
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
      localFilePath: null,
    );
  }

  Future<void> _importLocalAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      );

      final filePath = result?.files.single.path;
      if (filePath == null || filePath.trim().isEmpty) return;

      final file = File(filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file was not found.')),
        );
        return;
      }

      final request = _CustomSongRequest(
        sourceUrl: file.uri.toString(),
        title: _fileNameFromPath(filePath),
        artist: 'Local file',
        lyrics: '',
        youtubeVideoId: null,
        localFilePath: filePath,
      );
      await _loadCustomSong(request);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to import local audio file.')),
      );
    }
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final raw = normalized.split('/').last;
    final dotIndex = raw.lastIndexOf('.');
    if (dotIndex <= 0) return raw;
    return raw.substring(0, dotIndex);
  }

  Future<void> _loadCustomSong(_CustomSongRequest request) async {
    final service = ref.read(musicServiceProvider);

    // Fetch lyrics in background (non-blocking)
    String resolvedLyrics = request.lyrics.trim();
    final lyricsNeeded =
        resolvedLyrics.isEmpty &&
        (request.title.trim().isNotEmpty || request.artist.trim().isNotEmpty);

    try {
      // ── YouTube URL: try cobalt audio extraction first ──────────────────
      if (request.isYouTube) {
        // Show extraction loading state immediately
        setState(() {
          _isExtractingAudio = true;
          _customSong = request;
          _activeTrack = null;
          _isPlaying = false;
          _isLoading = false;
        });

        final audioUrl = await service.extractYouTubeAudioUrl(
          request.sourceUrl,
        );

        if (!mounted) return;
        setState(() => _isExtractingAudio = false);

        if (audioUrl != null && audioUrl.isNotEmpty) {
          // ✅ Cobalt succeeded — play as pure audio
          if (lyricsNeeded) {
            resolvedLyrics = await service.fetchLyrics(
              artist: request.artist,
              title: request.title,
            );
          }
          _disposeYoutubeController();
          setState(() {
            _customSong = request.copyWith(lyrics: resolvedLyrics);
            _activeTrack = null;
            _isPlaying = true;
            _isLoading = true;
          });
          await _player.stop();
          await _player.setUrl(audioUrl);
          await _player.play();
          return;
        }

        // ⚠️ Cobalt failed — fall back to YouTube video player
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
        if (lyricsNeeded) {
          resolvedLyrics = await service.fetchLyrics(
            artist: request.artist,
            title: request.title,
          );
        }
        if (!mounted) {
          controller.dispose();
          return;
        }
        setState(() {
          _customSong = request.copyWith(lyrics: resolvedLyrics);
          _youtubeController = controller;
          _activeTrack = null;
          _isPlaying = true;
          _isLoading = false;
        });
        return;
      }

      // ── Non-YouTube: play direct URL or local file ───────────────────
      if (lyricsNeeded) {
        resolvedLyrics = await service.fetchLyrics(
          artist: request.artist,
          title: request.title,
        );
      }
      _disposeYoutubeController();
      setState(() {
        _customSong = request.copyWith(lyrics: resolvedLyrics);
        _activeTrack = null;
        _isPlaying = true;
        _isLoading = true;
      });
      await _player.stop();
      if (request.localFilePath != null && request.localFilePath!.isNotEmpty) {
        await _player.setFilePath(request.localFilePath!);
      } else {
        await _player.setUrl(request.sourceUrl);
      }
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isLoading = false;
        _isExtractingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load that link. Try a direct MP3/M4A URL or YouTube link.',
          ),
        ),
      );
    }
  }

  Future<void> _openFullSong(MusicTrack track) async {
    final direct = Uri.tryParse(track.trackViewUrl.trim());
    final fallback = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${track.displayTitle} ${track.displayArtist}')}',
    );

    final launchedDirect =
        direct != null &&
        await launchUrl(direct, mode: LaunchMode.externalApplication);

    if (launchedDirect || !mounted) return;

    final launchedFallback = await launchUrl(
      fallback,
      mode: LaunchMode.externalApplication,
    );

    if (launchedFallback || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open full song source.')),
    );
  }

  // ─── Downloads ─────────────────────────────────────────────────────────╮

  Future<void> _downloadPreview(BuildContext context, MusicTrack track) async {
    final key = _trackKey(track);
    setState(() {
      _isDownloading = true;
      _lyricsTrackKey = key;
    });
    try {
      final file = await ref
          .read(musicServiceProvider)
          .downloadPreview(track: track);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            file == null ? 'No preview available.' : 'Saved to ${file.path}',
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

// ─── _CustomSongRequest ─────────────────────────────────────────────────────╮

class _CustomSongRequest {
  final String sourceUrl;
  final String title;
  final String artist;
  final String lyrics;
  final String? youtubeVideoId;
  final String? localFilePath;

  const _CustomSongRequest({
    required this.sourceUrl,
    required this.title,
    required this.artist,
    required this.lyrics,
    required this.youtubeVideoId,
    required this.localFilePath,
  });

  bool get isYouTube => youtubeVideoId != null && youtubeVideoId!.isNotEmpty;
  bool get isLocalFile => localFilePath != null && localFilePath!.isNotEmpty;
  String get displayTitle => title.isEmpty ? 'Custom song link' : title;
  String get displayArtist {
    if (artist.isNotEmpty) return artist;
    if (isLocalFile) return 'Imported from device';
    return 'User supplied link';
  }

  String get displayGenre {
    if (isYouTube) return 'YouTube';
    if (isLocalFile) return 'Local audio';
    return 'Direct audio';
  }

  _CustomSongRequest copyWith({String? lyrics}) {
    return _CustomSongRequest(
      sourceUrl: sourceUrl,
      title: title,
      artist: artist,
      lyrics: lyrics ?? this.lyrics,
      youtubeVideoId: youtubeVideoId,
      localFilePath: localFilePath,
    );
  }
}

// ─── _WaveformWidget ────────────────────────────────────────────────────────╮

class _WaveformWidget extends StatelessWidget {
  final AnimationController controller;
  const _WaveformWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final phase = (controller.value + i * 0.18) % 1.0;
            final height = 8 + 18 * math.sin(phase * math.pi).abs();
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── _AudioProgressStrip ────────────────────────────────────────────────────╮

class _AudioProgressStrip extends StatelessWidget {
  final AudioPlayer player;
  final bool isPlaying;

  const _AudioProgressStrip({required this.player, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durationSnap) {
        final duration = durationSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final clamped = position > duration ? duration : position;
            final maxMs =
                duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
            final progress = clamped.inMilliseconds.clamp(0, maxMs) / maxMs;

            return Column(
              children: [
                // Seekable progress bar
                GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(details.globalPosition);
                    final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
                    player.seek(
                      Duration(milliseconds: (ratio * maxMs).round()),
                    );
                  },
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.isNaN ? 0 : progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(clamped),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (duration.inMilliseconds > 0)
                      GestureDetector(
                        onTap: () => player.seek(Duration.zero),
                        child: const Text(
                          '↺ Restart',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    Text(
                      _fmt(duration),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    String z(int v) => v.toString().padLeft(2, '0');
    return '${d.inMinutes}:${z(d.inSeconds.remainder(60))}';
  }
}

// ─── _SongCard ──────────────────────────────────────────────────────────────╮

class _SongCard extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isLoading;
  final bool isDownloading;
  final VoidCallback onPlay;
  final VoidCallback onLyrics;
  final VoidCallback onOpenFullSong;
  final VoidCallback onDownload;

  const _SongCard({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.isLoading,
    required this.isDownloading,
    required this.onPlay,
    required this.onLyrics,
    required this.onOpenFullSong,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isPlaying || isLoading;
    return NeuContainer(
      borderRadius: BorderRadius.circular(14),
      color: isActive ? _kAccent : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.black,
                child:
                    track.artworkUrl.isNotEmpty
                        ? Image.network(
                          track.artworkUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.music_note_rounded,
                                color: _kAccent,
                                size: 30,
                              ),
                        )
                        : const Icon(
                          Icons.music_note_rounded,
                          color: _kAccent,
                          size: 30,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (track.displayAlbum.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.displayAlbum,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Previews are short. Tap Full Song for the complete track.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CardButton(
                        icon:
                            isLoading
                                ? Icons.hourglass_top_rounded
                                : isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                        label:
                            isLoading
                                ? '…'
                                : isPlaying
                                ? 'Pause'
                                : 'Play',
                        filled: true,
                        onPressed: onPlay,
                      ),
                      _CardButton(
                        icon: Icons.menu_book_rounded,
                        label: 'Lyrics',
                        onPressed: onLyrics,
                      ),
                      _CardButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'Full Song',
                        onPressed: onOpenFullSong,
                      ),
                      _CardButton(
                        icon:
                            isDownloading
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded,
                        label: '↓',
                        onPressed: isDownloading ? null : onDownload,
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

// ─── _CardButton ────────────────────────────────────────────────────────────╮

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _CardButton({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(offset: Offset(2, 2), color: Colors.black),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : Colors.black),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: filled ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _NeuBrutButton ─────────────────────────────────────────────────────────╮

class _NeuBrutButton extends StatelessWidget {
  final Color color;
  final Color textColor;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  const _NeuBrutButton({
    required this.color,
    required this.label,
    required this.icon,
    this.textColor = Colors.black,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.grey.shade300 : color,
          borderRadius: _kBorderRadius,
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: onPressed == null ? [] : _kShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: textColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
