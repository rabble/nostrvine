// ABOUTME: Service for signing videos with C2PA content credentials
// ABOUTME: Embeds provenance information into video files before upload

import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of a C2PA signing operation
class C2paSigningResult {
  const C2paSigningResult({
    required this.signedFilePath,
    required this.success,
    this.error,
  });

  /// Path to the signed video file
  final String signedFilePath;

  /// Whether signing was successful
  final bool success;

  /// Error message if signing failed
  final String? error;
}

/// Service for signing videos with C2PA content credentials.
///
/// C2PA (Coalition for Content Provenance and Authenticity) embeds
/// cryptographic provenance information directly into media files,
/// establishing the origin and history of digital content.
class C2paSigningService {
  C2paSigningService();

  final C2pa _c2pa = C2pa();
  static const String CLAIM_GENERATOR = 'DiVine/1.0';

  /// Signs a video file with C2PA content credentials.
  ///
  /// [videoPath] - Path to the video file to sign
  /// [aiTrainingOptOut] - When true, includes a CAWG training-mining assertion
  ///   marking all AI training and data mining uses as "notAllowed"
  ///
  /// Returns the path to the signed video file, or the original path if
  /// signing fails (signing is best-effort, not blocking).
  Future<C2paSigningResult> signVideo({
    required String videoPath,
    bool aiTrainingOptOut = true,
  }) async {
    try {
      Log.info(
        'Starting C2PA signing for video: $videoPath',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      // Verify input file exists
      final inputFile = File(videoPath);
      if (!inputFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Input file does not exist',
        );
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String claimGenerator =
          '${packageInfo.appName}/${packageInfo.version}';

      // Generate output path for signed video
      final directory = inputFile.parent.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signedPath = '$directory/c2pa_signed_$timestamp.mp4';

      final filename = inputFile.path.split('/').last;
      // Build manifest JSON for digital capture
      final manifestJsonSource = _buildManifestJson(
        claimGenerator,
        filename,
        DigitalSourceType.digitalCapture.url,
        aiTrainingOptOut: aiTrainingOptOut,
      );
      Log.info('prepared C2PA manifest json: $manifestJsonSource');

      // Create signer for RemoteSigning against proofsign
      final signer = _createSigner();

      // Sign the file
      await _c2pa.signFile(
        sourcePath: videoPath,
        destPath: signedPath,
        manifestJson: manifestJsonSource,
        signer: await signer,
      );

      // Verify signed file was created
      final signedFile = File(signedPath);
      if (!signedFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Signed file was not created',
        );
      }

      // Log.debug("replacing original video $videoPath with signed file $signedFile");
      inputFile.renameSync('${inputFile.path}.old');
      // Log.debug("original file renamed: ${iFileNew.path} ");
      final sFileNew = signedFile.renameSync(inputFile.path);
      Log.debug('signed file renamed: ${sFileNew.path} ');

      final signedSize = await sFileNew.length();
      Log.info(
        'C2PA signing complete: $sFileNew (${signedSize ~/ 1024} KB)',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      return C2paSigningResult(signedFilePath: sFileNew.path, success: true);
    } catch (e, stackTrace) {
      Log.error(
        'C2PA signing failed: $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );

      // Return original path - signing is best-effort, not blocking
      return C2paSigningResult(
        signedFilePath: videoPath,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Reads and validates C2PA manifest from a signed file.
  ///
  /// Returns a [ManifestStoreInfo] with parsed manifest data and validation
  /// info, or null if no manifest is found.
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    try {
      return await _c2pa.readManifestFromFile(filePath);
    } catch (e) {
      Log.warning(
        'Failed to read C2PA manifest: $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Gets the C2PA library version.
  Future<String?> getVersion() async {
    return _c2pa.getVersion();
  }

  /// Checks if hardware-backed signing is available on this device.
  ///
  /// Returns true if:
  /// - Android: StrongBox is available (Android 9.0+ with hardware support)
  /// - iOS: Secure Enclave is available (iPhone 5s+, not in Simulator)
  Future<bool> isHardwareSigningAvailable() async {
    return _c2pa.isHardwareSigningAvailable();
  }

  /// Exposes [_buildManifestJson] for testing.
  @visibleForTesting
  String buildManifestJsonPublic(
    String claimGenerator,
    String title,
    String digitalSourceUrl, {
    bool aiTrainingOptOut = true,
  }) => _buildManifestJson(
    claimGenerator,
    title,
    digitalSourceUrl,
    aiTrainingOptOut: aiTrainingOptOut,
  );

  /// Builds the manifest JSON for a freshly captured video.
  ///
  /// When [aiTrainingOptOut] is true, includes a `cawg.training-mining`
  /// assertion per the CAWG Training and Data Mining spec v1.1, marking
  /// all AI training, inference, generative training, and data mining
  /// uses as "notAllowed".
  String _buildManifestJson(
    String claimGenerator,
    String title,
    String digitalSourceUrl, {
    bool aiTrainingOptOut = true,
  }) {
    final trainingMiningAssertion = aiTrainingOptOut
        ? ','
              ' {"label": "cawg.training-mining",'
              ' "data": {"entries": {'
              ' "cawg.ai_training": {"use": "notAllowed"},'
              ' "cawg.ai_inference": {"use": "notAllowed"},'
              ' "cawg.ai_generative_training": {"use": "notAllowed"},'
              ' "cawg.data_mining": {"use": "notAllowed"}}}}'
        : '';

    return '''
{
  "claim_generator": "$claimGenerator",
  "title": "$title",
  "format": "video/mp4",
  "ingredients": [
        {
          "title": "$title",
          "format": "video/mp4",
          "relationship": "parentOf",
          "label": "c2pa.ingredient.v2"
        }
      ],
  "assertions": [
    {
      "label": "c2pa.actions.v2",
      "data": {
        "actions": [
          {
            "action": "c2pa.created",
            "digitalSourceType": "$digitalSourceUrl",
            "softwareAgent": "$claimGenerator"
          }
        ]
      }
    }$trainingMiningAssertion
  ]
}
''';
  }

  /// Creates a signer for C2PA operations.
  ///
  /// TODO: Replace with proper key management:
  /// - Use HardwareSigner for Secure Enclave (iOS) / StrongBox (Android)x
  /// - Generate per-user keys during onboarding
  /// - Store certificates securely
  /// - Support user-provided certificates via enrollment API
  Future<C2paSigner> _createSigner() async {
    var args = '?platform=';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android-specific code
      args += 'android';
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS-specific code
      args += 'ios';
    }

    return RemoteSigner(
      configurationUrl: SIGNING_SERVER_ENDPOINT + args,
      bearerToken: SIGNING_SERVER_TOKEN,
    );
  }

  // add ?platform=android or ios
  static const String SIGNING_SERVER_ENDPOINT = String.fromEnvironment(
    'PROOFMODE_SIGNING_SERVER_ENDPOINT',
  );

  static const String SIGNING_SERVER_TOKEN = String.fromEnvironment(
    'PROOFMODE_SIGNING_SERVER_TOKEN',
  );
}
