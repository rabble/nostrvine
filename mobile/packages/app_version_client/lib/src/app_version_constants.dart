/// Constants for the GitHub Releases API integration.
abstract class AppVersionConstants {
  /// GitHub repository owner.
  static const repoOwner = 'divinevideo';

  /// GitHub repository name.
  static const repoName = 'divine-mobile';

  /// Duration to cache the GitHub API response.
  static const cacheTtl = Duration(hours: 24);

  /// Regex to extract minimum_version from release body HTML comment.
  static final minimumVersionPattern = RegExp(
    r'<!--\s*minimum_version:\s*([\d.]+)\s*-->',
  );

  /// Regex to extract bold items from Markdown bullet points.
  /// Matches lines like: `- **Resumable uploads** — description`
  static final highlightPattern = RegExp(
    r'^\s*[-*]\s+\*\*([^*]+)\*\*',
    multiLine: true,
  );
}
