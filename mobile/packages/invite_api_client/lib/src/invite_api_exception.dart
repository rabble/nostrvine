class InviteApiException implements Exception {
  const InviteApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() =>
      'InviteApiException(message: $message, statusCode: $statusCode)';
}
