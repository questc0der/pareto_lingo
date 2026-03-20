import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';

class YoutubeRemoteDataSource {
  const YoutubeRemoteDataSource();

  Future<List<LearningVideo>> fetchLearningVideos({
    required String languageCode,
  }) async {
    final selectedLanguage = languageOptionByCode(languageCode);
    return _catalogByLanguage[selectedLanguage.code] ?? _catalogFallback;
  }

  static const Map<String, List<LearningVideo>> _catalogByLanguage = {
    'fr': _catalogFrench,
    'es': _catalogSpanish,
    'de': _catalogGerman,
  };

  static const _video1 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
  static const _video2 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';
  static const _video3 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4';
  static const _video4 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4';
  static const _video5 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

  static const List<LearningVideo> _catalogFrench = [
    LearningVideo(
      id: 'fr-1',
      title: 'French street phrases • mini immersion',
      thumbnailUrl:
          'https://images.pexels.com/photos/161901/paris-skyline-france-landmark-161901.jpeg',
      videoUrl: _video1,
    ),
    LearningVideo(
      id: 'fr-2',
      title: 'Café order role-play in French',
      thumbnailUrl:
          'https://images.pexels.com/photos/1855214/pexels-photo-1855214.jpeg',
      videoUrl: _video2,
    ),
    LearningVideo(
      id: 'fr-3',
      title: 'French listening sprint • 30 sec',
      thumbnailUrl:
          'https://images.pexels.com/photos/699466/pexels-photo-699466.jpeg',
      videoUrl: _video3,
    ),
  ];

  static const List<LearningVideo> _catalogSpanish = [
    LearningVideo(
      id: 'es-1',
      title: 'Spanish market chat • quick phrases',
      thumbnailUrl:
          'https://images.pexels.com/photos/1198507/pexels-photo-1198507.jpeg',
      videoUrl: _video2,
    ),
    LearningVideo(
      id: 'es-2',
      title: 'Travel Spanish • ask and answer',
      thumbnailUrl:
          'https://images.pexels.com/photos/356830/pexels-photo-356830.jpeg',
      videoUrl: _video4,
    ),
    LearningVideo(
      id: 'es-3',
      title: 'Spanish vibe clip • repeat after me',
      thumbnailUrl:
          'https://images.pexels.com/photos/161154/stained-glass-window-spanish-city-cathedral-161154.jpeg',
      videoUrl: _video5,
    ),
  ];

  static const List<LearningVideo> _catalogGerman = [
    LearningVideo(
      id: 'de-1',
      title: 'German station dialogue • short form',
      thumbnailUrl:
          'https://images.pexels.com/photos/1105766/pexels-photo-1105766.jpeg',
      videoUrl: _video3,
    ),
    LearningVideo(
      id: 'de-2',
      title: 'Daily German mini conversation',
      thumbnailUrl:
          'https://images.pexels.com/photos/417344/pexels-photo-417344.jpeg',
      videoUrl: _video1,
    ),
    LearningVideo(
      id: 'de-3',
      title: 'German listening pulse • fast shadow',
      thumbnailUrl:
          'https://images.pexels.com/photos/2570063/pexels-photo-2570063.jpeg',
      videoUrl: _video4,
    ),
  ];

  static const List<LearningVideo> _catalogFallback = [
    LearningVideo(
      id: 'fallback-1',
      title: 'Fun short • everyday phrases',
      thumbnailUrl:
          'https://images.pexels.com/photos/316902/pexels-photo-316902.jpeg',
      videoUrl: _video1,
    ),
    LearningVideo(
      id: 'fallback-2',
      title: 'Fun short • repeat and shadow',
      thumbnailUrl:
          'https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg',
      videoUrl: _video2,
    ),
  ];
}
