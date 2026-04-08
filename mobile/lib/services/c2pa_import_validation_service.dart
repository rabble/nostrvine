import 'package:c2pa_flutter/c2pa.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Validates C2PA Content Credentials on imported video files.
class C2paImportValidationService {
  C2paImportValidationService({required C2paSigningService c2paSigningService})
    : _c2paSigningService = c2paSigningService;

  final C2paSigningService _c2paSigningService;

  Future<C2paImportResult> validateFile(String filePath) async {
    try {
      Log.info(
        'Validating C2PA manifest for import: $filePath',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
      );

      final manifestStore = await _c2paSigningService.readManifest(filePath);

      if (manifestStore == null) {
        Log.info(
          'No C2PA manifest found in file',
          name: 'C2paImportValidationService',
          category: LogCategory.video,
        );
        return C2paImportResult.noCredentials();
      }

      if (manifestStore.validationStatus == ValidationStatus.invalid) {
        Log.warning(
          'C2PA manifest has invalid signature',
          name: 'C2paImportValidationService',
          category: LogCategory.video,
        );
        return C2paImportResult.invalidSignature();
      }

      final active = manifestStore.active;
      if (active == null) {
        return C2paImportResult.noCredentials();
      }

      final claimGenerator = active.claimGenerator ?? 'Unknown';
      final title = active.title;
      final issuer = active.signature?.issuer;
      final signedAt = active.signature?.signedAt;

      final sourceTypeUrl = _extractDigitalSourceType(active.assertions);
      final classification = C2paSourceClassification.fromDigitalSourceTypeUrl(
        sourceTypeUrl,
      );

      Log.info(
        'C2PA validation complete: generator=$claimGenerator, '
        'sourceType=$classification, issuer=$issuer',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
      );

      if (classification == C2paSourceClassification.aiGenerated ||
          classification == C2paSourceClassification.compositeWithAi) {
        return C2paImportResult.aiGenerated(
          claimGenerator: claimGenerator,
          digitalSourceTypeRaw: sourceTypeUrl,
        );
      }

      return C2paImportResult.verified(
        claimGenerator: claimGenerator,
        digitalSourceType: classification,
        digitalSourceTypeRaw: sourceTypeUrl ?? '',
        signatureIssuer: issuer,
        signedAt: signedAt,
        title: title,
      );
    } catch (e, stackTrace) {
      Log.error(
        'C2PA import validation failed: $e',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return C2paImportResult.error(e.toString());
    }
  }

  String? _extractDigitalSourceType(List<AssertionInfo> assertions) {
    for (final assertion in assertions) {
      if (assertion.label != 'c2pa.actions' &&
          assertion.label != 'c2pa.actions.v2') {
        continue;
      }
      final actions = assertion.data['actions'];
      if (actions is! List) continue;

      for (final action in actions) {
        if (action is! Map<String, dynamic>) continue;
        final sourceType = action['digitalSourceType'] as String?;
        if (sourceType != null) return sourceType;
      }
    }
    return null;
  }
}
