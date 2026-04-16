import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pareto_lingo/features/music/domain/entities/music_track.dart';

class MusicService {
  final http.Client _client;

  MusicService(this._client);

  Future<List<MusicTrack>> searchSongs({
    required String query,
    required String languageCode,
    int limit = 20,
  }) async {
    final term = _buildSearchTerm(query, languageCode);
    final countries = _candidateCountries(languageCode);

    for (final country in countries) {
      try {
        final uri = Uri.https('itunes.apple.com', '/search', {
          'term': term,
          'media': 'music',
          'entity': 'song',
          'limit': '$limit',
          'country': country,
        });

        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (decoded['results'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_trackFromJson)
            .where((track) => track.previewUrl.isNotEmpty)
            .toList(growable: false);

        if (results.isNotEmpty) {
          return results;
        }
      } catch (_) {
        continue;
      }
    }

    return _fallbackTracks(languageCode, limit);
  }

  Future<String> fetchLyrics({
    required String artist,
    required String title,
  }) async {
    final safeArtist = Uri.encodeComponent(artist.trim());
    final safeTitle = Uri.encodeComponent(title.trim());

    if (safeArtist.isEmpty || safeTitle.isEmpty) return '';

    final uri = Uri.parse('https://api.lyrics.ovh/v1/$safeArtist/$safeTitle');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['lyrics']?.toString() ?? '').trim();
  }

  Future<File?> downloadPreview({required MusicTrack track}) async {
    if (track.previewUrl.isEmpty) return null;

    return downloadAudioSource(
      url: track.previewUrl,
      fileNameHint: '${track.artistName} - ${track.trackName}',
      fallbackExtension: 'm4a',
    );
  }

  Future<File?> downloadAudioSource({
    required String url,
    required String fileNameHint,
    String fallbackExtension = 'mp3',
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.parse(trimmed);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to download audio source.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/music_downloads');
    if (!downloadsDir.existsSync()) {
      await downloadsDir.create(recursive: true);
    }

    final extension =
        _resolveAudioExtension(uri, response.headers) ?? fallbackExtension;
    final safeName = _safeFileName(fileNameHint);
    final file = File('${downloadsDir.path}/$safeName.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  String _buildSearchTerm(String query, String languageCode) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) return trimmed;

    return switch (languageCode.toLowerCase()) {
      'zh' => 'chinese songs with lyrics',
      'en' => 'english songs with lyrics',
      _ => 'french songs with lyrics',
    };
  }

  List<String> _candidateCountries(String languageCode) {
    return switch (languageCode.toLowerCase()) {
      'zh' => const ['CN', 'US', 'TW'],
      'en' => const ['US', 'GB', 'CA'],
      _ => const ['FR', 'BE', 'CA', 'US'],
    };
  }

  List<MusicTrack> _fallbackTracks(String languageCode, int limit) {
    final library = switch (languageCode.toLowerCase()) {
      'zh' => _mandarinFallbackTracks,
      'en' => _englishFallbackTracks,
      _ => _frenchFallbackTracks,
    };

    return library.take(limit).toList(growable: false);
  }

  MusicTrack _trackFromJson(Map<String, dynamic> json) {
    return MusicTrack(
      trackId: (json['trackId'] as num?)?.toInt() ?? 0,
      trackName: json['trackName']?.toString() ?? '',
      artistName: json['artistName']?.toString() ?? '',
      collectionName: json['collectionName']?.toString() ?? '',
      artworkUrl: json['artworkUrl100']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString() ?? '',
      trackViewUrl: json['trackViewUrl']?.toString() ?? '',
      primaryGenreName: json['primaryGenreName']?.toString() ?? '',
    );
  }

  String _safeFileName(String input) {
    final safe =
        input
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    if (safe.length <= 80) return safe;
    return safe.substring(0, 80);
  }

  String? _resolveAudioExtension(Uri uri, Map<String, String> headers) {
    final contentType = headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('audio/mpeg') ||
        contentType.contains('audio/mp3')) {
      return 'mp3';
    }
    if (contentType.contains('audio/mp4') ||
        contentType.contains('audio/x-m4a')) {
      return 'm4a';
    }
    if (contentType.contains('audio/aac')) {
      return 'aac';
    }
    if (contentType.contains('audio/wav')) {
      return 'wav';
    }

    if (uri.pathSegments.isNotEmpty) {
      final candidate = uri.pathSegments.last.split('.').last.toLowerCase();
      if (candidate == 'mp3' ||
          candidate == 'm4a' ||
          candidate == 'aac' ||
          candidate == 'wav' ||
          candidate == 'flac' ||
          candidate == 'ogg') {
        return candidate;
      }
    }

    return null;
  }

  static final List<MusicTrack> _englishFallbackTracks = [
    const MusicTrack(
      trackId: 1,
      trackName: 'Hello',
      artistName: 'Adele',
      collectionName: '25',
      artworkUrl: '',
      previewUrl:
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/00/00/00/00000000-0000-0000-0000-000000000000/mzaf_0000000000000000000000.plus.aac.p.m4a',
      trackViewUrl: '',
      primaryGenreName: 'Pop',
    ),
    const MusicTrack(
      trackId: 2,
      trackName: 'Someone Like You',
      artistName: 'Adele',
      collectionName: '21',
      artworkUrl: '',
      previewUrl:
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/00/00/00/00000000-0000-0000-0000-000000000000/mzaf_0000000000000000000001.plus.aac.p.m4a',
      trackViewUrl: '',
      primaryGenreName: 'Pop',
    ),
  ];

  static final List<MusicTrack> _frenchFallbackTracks = [
    const MusicTrack(
      trackId: 11,
      trackName: 'Dernière danse',
      artistName: 'Indila',
      collectionName: 'Mini World',
      artworkUrl: '',
      previewUrl:
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/00/00/00/00000000-0000-0000-0000-000000000000/mzaf_0000000000000000000002.plus.aac.p.m4a',
      trackViewUrl: '',
      primaryGenreName: 'Pop',
    ),
  ];

  static final List<MusicTrack> _mandarinFallbackTracks = [
    const MusicTrack(
      trackId: 21,
      trackName: '小幸运',
      artistName: 'Hebe Tien',
      collectionName: 'My Love',
      artworkUrl: '',
      previewUrl:
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/00/00/00/00000000-0000-0000-0000-000000000000/mzaf_0000000000000000000003.plus.aac.p.m4a',
      trackViewUrl: '',
      primaryGenreName: 'Mandopop',
    ),
  ];
}
