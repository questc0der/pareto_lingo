class MusicTrack {
  final int trackId;
  final String trackName;
  final String artistName;
  final String collectionName;
  final String artworkUrl;
  final String previewUrl;
  final String trackViewUrl;
  final String primaryGenreName;

  const MusicTrack({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    required this.artworkUrl,
    required this.previewUrl,
    required this.trackViewUrl,
    required this.primaryGenreName,
  });

  String get displayTitle =>
      trackName.trim().isEmpty ? 'Unknown song' : trackName;
  String get displayArtist =>
      artistName.trim().isEmpty ? 'Unknown artist' : artistName;
  String get displayAlbum =>
      collectionName.trim().isEmpty ? '' : collectionName;
}
