// ABOUTME: Service for signing videos with C2PA content credentials
// ABOUTME: Embeds provenance information into video files before upload

import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/services/c2pa_identity_manifest_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

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
  C2paSigningService({
    C2pa? c2pa,
    C2paIdentityManifestService? manifestService,
  }) : _c2pa = c2pa ?? C2pa(),
       _manifestService = manifestService ?? C2paIdentityManifestService();

  final C2pa _c2pa;
  final C2paIdentityManifestService _manifestService;

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
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
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
      final manifestResult = _manifestService.buildCreatedVideoManifest(
        claimGenerator: claimGenerator,
        title: filename,
        sourceType: DigitalSourceType.digitalCapture,
        aiTrainingOptOut: aiTrainingOptOut,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: cawgIdentityAssertion,
        enableAdvancedCawgEmbedding: enableAdvancedCawgEmbedding,
      );
      if (manifestResult.requiresAdvancedEmbedding) {
        Log.warning(
          'Full CAWG identity embedding requires advanced placeholder support; '
          'signing without embedded cawg.identity for now',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
      }
      Log.info('prepared C2PA manifest json: ${manifestResult.manifestJson}');

      // Create signer for RemoteSigning against proofsign
      final signer = _createSigner();

      // Sign the file
      await _c2pa.signFile(
        sourcePath: videoPath,
        destPath: signedPath,
        manifestJson: manifestResult.manifestJson,
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
  }) => _manifestService
      .buildCreatedVideoManifest(
        claimGenerator: claimGenerator,
        title: title,
        sourceType:
            DigitalSourceType.fromUrl(digitalSourceUrl) ??
            DigitalSourceType.digitalCapture,
        aiTrainingOptOut: aiTrainingOptOut,
      )
      .manifestJson;

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
