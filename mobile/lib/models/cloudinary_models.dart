// ABOUTME: Data models for Cloudinary signed upload and response handling
// ABOUTME: Handles signed upload parameters and upload response parsing for Cloudinary integration

/// Cloudinary signed upload parameters from backend
class CloudinarySignedUpload {
  final String uploadUrl;
  final Map<String, String> uploadParams;
  final int expiresIn;
  
  const CloudinarySignedUpload({
    required this.uploadUrl,
    required this.uploadParams,
    required this.expiresIn,
  });
  
  factory CloudinarySignedUpload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    
    // Convert all values to strings for form data
    final params = <String, String>{
      'signature': data['signature'] as String,
      'timestamp': data['timestamp'].toString(),
      'api_key': data['api_key'] as String,
      'upload_preset': data['upload_preset'] as String,
      'public_id': data['public_id'] as String,
      'context': data['context'] as String,
      'folder': data['folder'] as String,
    };
    
    return CloudinarySignedUpload(
      uploadUrl: json['upload_url'] as String,
      uploadParams: params,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Cloudinary upload response
class CloudinaryUploadResponse {
  final String publicId;
  final String secureUrl;
  final String url;
  final String format;
  final int bytes;
  final int width;
  final int height;
  final String resourceType;
  final DateTime createdAt;
  final Map<String, dynamic>? context;
  final String? signature;
  
  const CloudinaryUploadResponse({
    required this.publicId,
    required this.secureUrl,
    required this.url,
    required this.format,
    required this.bytes,
    required this.width,
    required this.height,
    required this.resourceType,
    required this.createdAt,
    this.context,
    this.signature,
  });
  
  factory CloudinaryUploadResponse.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResponse(
      publicId: json['public_id'] as String,
      secureUrl: json['secure_url'] as String,
      url: json['url'] as String,
      format: json['format'] as String,
      bytes: json['bytes'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      resourceType: json['resource_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      context: json['context'] as Map<String, dynamic>?,
      signature: json['signature'] as String?,
    );
  }
  
  /// Get the public URL for the uploaded file
  String get publicUrl => secureUrl;
  
  /// Extract user pubkey from context if available
  String? get userPubkey {
    if (context == null) return null;
    final contextStr = context.toString();
    final match = RegExp(r'pubkey=([a-f0-9]+)').firstMatch(contextStr);
    return match?.group(1);
  }
}