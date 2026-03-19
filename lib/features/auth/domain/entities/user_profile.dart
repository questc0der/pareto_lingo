class UserProfile {
  final String displayName;
  final String? profileImageUrl;
  final String learningLanguage;

  const UserProfile({
    required this.displayName,
    required this.learningLanguage,
    this.profileImageUrl,
  });
}
