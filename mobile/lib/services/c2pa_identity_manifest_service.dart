import 'dart:convert';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:meta/meta.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

@immutable
class C2paIdentityManifestBuildResult {
  const C2paIdentityManifestBuildResult({
    required this.manifestDefinition,
    required this.requiresAdvancedEmbedding,
  });

  final ManifestDefinition manifestDefinition;
  final bool requiresAdvancedEmbedding;

  String get manifestJson => manifestDefinition.toJsonString();
}

class C2paIdentityManifestService {
  C2paIdentityManifestService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  C2paIdentityManifestBuildResult buildCreatedVideoManifest({
    required String claimGenerator,
    required String title,
    required DigitalSourceType sourceType,
    bool aiTrainingOptOut = true,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) {
    final requiresAdvancedEmbedding =
        enableAdvancedCawgEmbedding && cawgIdentityAssertion != null;

    final manifest = ManifestDefinition(
      title: title,
      claimGeneratorInfo: <ClaimGeneratorInfo>[
        _parseClaimGenerator(claimGenerator),
      ],
      format: 'video/mp4',
      ingredients: <Ingredient>[
        Ingredient(
          title: title,
          format: 'video/mp4',
          relationship: Relationship.parentOf,
          label: 'c2pa.ingredient.v2',
        ),
      ],
      assertions: <AssertionDefinition>[
        CustomAssertion(
          label: 'c2pa.actions.v2',
          data: <String, dynamic>{
            'actions': <Map<String, dynamic>>[
              Action.created(
                sourceType: sourceType,
                softwareAgent: claimGenerator,
                when: _now().toUtc().toIso8601String(),
              ).toJson(),
            ],
          },
        ),
        if (aiTrainingOptOut) _buildTrainingMiningAssertion(),
        if (creatorBindingAssertion != null)
          CustomAssertion(
            label: creatorBindingAssertion.assertionLabel,
            data:
                jsonDecode(creatorBindingAssertion.payloadJson)
                    as Map<String, dynamic>,
          ),
        if (cawgIdentityAssertion != null && !requiresAdvancedEmbedding)
          CustomAssertion(
            label: 'cawg.identity',
            data: Map<String, dynamic>.of(cawgIdentityAssertion),
          ),
      ],
    );

    return C2paIdentityManifestBuildResult(
      manifestDefinition: manifest,
      requiresAdvancedEmbedding: requiresAdvancedEmbedding,
    );
  }

  ClaimGeneratorInfo _parseClaimGenerator(String claimGenerator) {
    final separatorIndex = claimGenerator.lastIndexOf('/');
    if (separatorIndex <= 0 || separatorIndex == claimGenerator.length - 1) {
      return ClaimGeneratorInfo(name: claimGenerator);
    }

    return ClaimGeneratorInfo(
      name: claimGenerator.substring(0, separatorIndex),
      version: claimGenerator.substring(separatorIndex + 1),
    );
  }

  CustomAssertion _buildTrainingMiningAssertion() {
    return const CustomAssertion(
      label: 'cawg.training-mining',
      data: <String, dynamic>{
        'entries': <String, dynamic>{
          'cawg.ai_training': <String, String>{'use': 'notAllowed'},
          'cawg.ai_inference': <String, String>{'use': 'notAllowed'},
          'cawg.ai_generative_training': <String, String>{'use': 'notAllowed'},
          'cawg.data_mining': <String, String>{'use': 'notAllowed'},
        },
      },
    );
  }
}
