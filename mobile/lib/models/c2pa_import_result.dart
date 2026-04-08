import 'package:equatable/equatable.dart';

/// Classification of a C2PA digital source type into categories
/// relevant to diVine's human-content-only policy.
enum C2paSourceClassification {
  humanCreated,
  aiGenerated,
  compositeWithAi,
  unknown
  ;

  static const _humanSourceTypes = {
    'digitalCapture',
    'digitalCreation',
    'humanEdits',
    'compositeCapture',
    'screenCapture',
    'virtualRecording',
    'negativeFilm',
    'positiveFilm',
    'print',
    'composite',
    'dataDrivenMedia',
    'digitalArt',
  };

  static const _aiSourceTypes = {
    'trainedAlgorithmicMedia',
    'trainedAlgorithmicData',
    'algorithmicMedia',
    'algorithmicallyEnhanced',
  };

  static const _compositeAiSourceTypes = {
    'compositeWithTrainedAlgorithmicMedia',
    'compositeSynthetic',
  };

  static C2paSourceClassification fromDigitalSourceTypeUrl(String? url) {
    if (url == null) return unknown;
    final type = url.split('/').last;
    if (_humanSourceTypes.contains(type)) return humanCreated;
    if (_aiSourceTypes.contains(type)) return aiGenerated;
    if (_compositeAiSourceTypes.contains(type)) return compositeWithAi;
    return unknown;
  }
}

enum C2paImportStatus {
  verified,
  noCredentials,
  aiGenerated,
  invalidSignature,
  error,
}

class C2paImportResult extends Equatable {
  const C2paImportResult._({
    required this.status,
    this.claimGenerator,
    this.digitalSourceType,
    this.digitalSourceTypeRaw,
    this.signatureIssuer,
    this.signedAt,
    this.title,
    this.rejectionReason,
  });

  factory C2paImportResult.verified({
    required String claimGenerator,
    required C2paSourceClassification digitalSourceType,
    required String digitalSourceTypeRaw,
    String? signatureIssuer,
    DateTime? signedAt,
    String? title,
  }) {
    return C2paImportResult._(
      status: C2paImportStatus.verified,
      claimGenerator: claimGenerator,
      digitalSourceType: digitalSourceType,
      digitalSourceTypeRaw: digitalSourceTypeRaw,
      signatureIssuer: signatureIssuer,
      signedAt: signedAt,
      title: title,
    );
  }

  factory C2paImportResult.noCredentials() {
    return const C2paImportResult._(status: C2paImportStatus.noCredentials);
  }

  factory C2paImportResult.aiGenerated({
    String? claimGenerator,
    String? digitalSourceTypeRaw,
  }) {
    return C2paImportResult._(
      status: C2paImportStatus.aiGenerated,
      claimGenerator: claimGenerator,
      digitalSourceType: C2paSourceClassification.aiGenerated,
      digitalSourceTypeRaw: digitalSourceTypeRaw,
    );
  }

  factory C2paImportResult.invalidSignature() {
    return const C2paImportResult._(
      status: C2paImportStatus.invalidSignature,
    );
  }

  factory C2paImportResult.error(String reason) {
    return C2paImportResult._(
      status: C2paImportStatus.error,
      rejectionReason: reason,
    );
  }

  final C2paImportStatus status;
  final String? claimGenerator;
  final C2paSourceClassification? digitalSourceType;
  final String? digitalSourceTypeRaw;
  final String? signatureIssuer;
  final DateTime? signedAt;
  final String? title;
  final String? rejectionReason;

  bool get isAccepted => status == C2paImportStatus.verified;

  String? get sourceAppName {
    if (claimGenerator == null) return null;
    final parts = claimGenerator!.split('/');
    return parts.first;
  }

  @override
  List<Object?> get props => [
    status,
    claimGenerator,
    digitalSourceType,
    digitalSourceTypeRaw,
    signatureIssuer,
    signedAt,
    title,
    rejectionReason,
  ];
}
