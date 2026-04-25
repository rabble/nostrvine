class InviteApiException implements Exception {
  const InviteApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.code,
    this.creatorSlug,
    this.creatorDisplayName,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? code;
  final String? creatorSlug;
  final String? creatorDisplayName;

  @override
  String toString() =>
      'InviteApiException(message: $message, statusCode: $statusCode, '
      'code: $code)';
}
