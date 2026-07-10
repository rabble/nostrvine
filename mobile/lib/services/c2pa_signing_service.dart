// ABOUTME: Service for signing videos with C2PA content credentials
// ABOUTME: Embeds provenance information into video files before upload

import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/c2pa_identity_manifest_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

/// C2PA edit actions recorded when carrying a manifest forward onto a
/// re-encoded ("derived") video via [C2paSigningService.resignDerived].
abstract class C2paEditActions {
  /// The derived file is an editorial transformation of its source — e.g. a
  /// watermark / overlay burned into the frame.
  ///
  /// Deliberately not `c2pa.watermarked`: the spec reserves that action for
  /// *invisible* soft-binding watermarks and requires an accompanying
  /// soft-binding assertion (C2PA 2.2 §18.14.5). `c2pa.transcoded` is also
  /// wrong — the spec defines it as a non-editorial transformation, and a
  /// visible overlay is editorial.
  static const String edited = 'c2pa.edited';
}

/// High-level reason a C2PA signing operation failed.
enum C2paSigningFailureReason {
  inputMissing,
  outputMissing,
  tls,
  network,
  other,
}

/// Result of a C2PA signing operation
class C2paSigningResult {
  const C2paSigningResult({
    required this.signedFilePath,
    required this.success,
    this.error,
    this.failureReason,
  });

  /// Path to the signed video file
  final String signedFilePath;

  /// Whether signing was successful
  final bool success;

  /// Error message if signing failed
  final String? error;

  /// Machine-readable reason when signing failed.
  final C2paSigningFailureReason? failureReason;
}

/// Service for signing videos with C2PA content credentials.
///
/// C2PA (Coalition for Content Provenance and Authenticity) embeds
/// cryptographic provenance information directly into media files,
/// establishing the origin and history of digital content.
class C2paSigningService {
  C2paSigningService({C2pa? c2pa, C2paIdentityManifestService? manifestService})
    : _c2pa = c2pa ?? C2pa(),
      _manifestService = manifestService ?? C2paIdentityManifestService();

  final C2pa _c2pa;
  final C2paIdentityManifestService _manifestService;

  static const String _videoMimeType = 'video/mp4';

  /// Signs a video file with C2PA content credentials.
  ///
  /// [videoPath] - Path to the video file to sign
  ///
  /// The CAWG `training-mining` assertion (opt-out of AI training and data
  /// mining) is embedded unconditionally as a matter of Divine policy.
  /// See `mobile/docs/AI_TRAINING_POLICY.md`.
  ///
  /// Returns the path to the signed video file, or the original path if
  /// signing fails (signing is best-effort, not blocking).
  Future<C2paSigningResult> signVideo({
    required String videoPath,
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
          failureReason: C2paSigningFailureReason.inputMissing,
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
          failureReason: C2paSigningFailureReason.outputMissing,
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
      final failureReason = classifyFailureReason(e);
      Log.error(
        'C2PA signing failed (${failureReason.name}): $e',
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
        failureReason: failureReason,
      );
    }
  }

  /// Carries an existing C2PA manifest forward onto a *derived* video file.
  ///
  /// [outputPath] is a freshly re-encoded file — an aspect-ratio crop or a
  /// watermark burn-in — that has lost the provenance embedded in its source.
  /// [sourcePath] is the already-signed original it was produced from. The
  /// source's active manifest is attached as a `parentOf` ingredient, [action]
  /// (a `c2pa.*` edit action such as [C2paEditActions.edited]) is recorded,
  /// and the result is signed and embedded back into [outputPath] in place.
  ///
  /// Returns `success: false` without touching [outputPath] when [sourcePath]
  /// carries no manifest — third-party downloads are never given fabricated
  /// provenance. Signing is best-effort and never throws.
  Future<C2paSigningResult> resignDerived({
    required String outputPath,
    required String sourcePath,
    required String action,
  }) async {
    try {
      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Output file does not exist',
        );
      }

      // Gate: only carry provenance forward when the source actually has some.
      final sourceManifest = await readManifest(sourcePath);
      if (sourceManifest?.activeManifest == null) {
        Log.info(
          'Skipping derived re-sign: source has no manifest to carry forward',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Source has no manifest to carry forward',
        );
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String claimGenerator =
          '${packageInfo.appName}/${packageInfo.version}';
      final String outputTitle = outputFile.path.split('/').last;

      final manifestJson = _manifestService
          .buildDerivedVideoManifest(
            claimGenerator: claimGenerator,
            title: outputTitle,
          )
          .manifestJson;

      final builder = await _c2pa.createBuilder(manifestJson);
      try {
        builder.setIntent(ManifestIntent.edit);

        final sourceBytes = await File(sourcePath).readAsBytes();
        await builder.addIngredient(
          data: sourceBytes,
          mimeType: _videoMimeType,
          config: IngredientConfig(
            title: sourcePath.split('/').last,
            relationship: Relationship.parentOf,
          ),
        );

        builder.addAction(
          ActionConfig(
            action: action,
            softwareAgent: claimGenerator,
            when: DateTime.now().toUtc(),
          ),
        );

        final outputBytes = await outputFile.readAsBytes();
        final signer = await _createSigner();
        final result = await builder.sign(
          sourceData: outputBytes,
          mimeType: _videoMimeType,
          signer: signer,
        );

        await outputFile.writeAsBytes(result.signedData, flush: true);

        Log.info(
          'C2PA manifest carried forward onto derived file '
          '($action): $outputPath (${result.signedData.length ~/ 1024} KB)',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );

        return C2paSigningResult(signedFilePath: outputPath, success: true);
      } finally {
        builder.dispose();
      }
    } catch (e, stackTrace) {
      Log.error(
        'C2PA derived re-sign failed: $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );

      // Best-effort: leave the (unsigned) re-encoded file as-is on failure.
      return C2paSigningResult(
        signedFilePath: outputPath,
        success: false,
        error: e.toString(),
      );
    }
  }

  @visibleForTesting
  static C2paSigningFailureReason classifyFailureReason(Object error) {
    final message = switch (error) {
      PlatformException(:final code, :final message, :final details) =>
        '$code $message $details'.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };

    if (_containsAny(message, const [
      'tls',
      'ssl',
      'secure connection',
      'certificate',
      'cert chain',
      'trust',
      'handshake',
    ])) {
      return C2paSigningFailureReason.tls;
    }

    if (_containsAny(message, const [
      'network',
      'not connected',
      'connect',
      'connection',
      'timed out',
      'timeout',
      'offline',
      'host',
      'dns',
      'socket',
      'internet',
      'reset by peer',
    ])) {
      return C2paSigningFailureReason.network;
    }

    return C2paSigningFailureReason.other;
  }

  static bool _containsAny(String message, List<String> needles) {
    return needles.any(message.contains);
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

  /// Exposes the manifest JSON for testing.
  @visibleForTesting
  String buildManifestJsonPublic(
    String claimGenerator,
    String title,
    String digitalSourceUrl,
  ) => _manifestService
      .buildCreatedVideoManifest(
        claimGenerator: claimGenerator,
        title: title,
        sourceType:
            DigitalSourceType.fromUrl(digitalSourceUrl) ??
            DigitalSourceType.digitalCapture,
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
