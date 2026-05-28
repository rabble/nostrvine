// ABOUTME: Unit tests for FeatureRequestCubit — submit lifecycle including
// ABOUTME: empty-field early return, success, server-false failure, and
// ABOUTME: thrown-exception failure with addError.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';

void main() {
  group(FeatureRequestCubit, () {
    SubmitFeatureRequestAction buildSubmit({
      bool returnValue = true,
      Object? throwError,
    }) {
      return ({
        required String subject,
        required String description,
        required String usefulness,
        required String whenToUse,
        String? userPubkey,
      }) async {
        if (throwError != null) throw throwError;
        return returnValue;
      };
    }

    blocTest<FeatureRequestCubit, FeatureRequestState>(
      'submit happy path emits submitting then success',
      build: () => FeatureRequestCubit(submitFeatureRequest: buildSubmit()),
      act: (cubit) => cubit.submit(
        subject: 'New thing',
        description: 'It would help me do X',
        usefulness: '',
        whenToUse: '',
      ),
      expect: () => [
        const FeatureRequestState(status: FeatureRequestStatus.submitting),
        const FeatureRequestState(status: FeatureRequestStatus.success),
      ],
    );

    blocTest<FeatureRequestCubit, FeatureRequestState>(
      'submit is a no-op when subject is empty',
      build: () => FeatureRequestCubit(submitFeatureRequest: buildSubmit()),
      act: (cubit) => cubit.submit(
        subject: '   ',
        description: 'd',
        usefulness: '',
        whenToUse: '',
      ),
      expect: () => const <FeatureRequestState>[],
    );

    blocTest<FeatureRequestCubit, FeatureRequestState>(
      'submit emits failure when the service returns false',
      build: () => FeatureRequestCubit(
        submitFeatureRequest: buildSubmit(returnValue: false),
      ),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        usefulness: '',
        whenToUse: '',
      ),
      expect: () => [
        const FeatureRequestState(status: FeatureRequestStatus.submitting),
        const FeatureRequestState(status: FeatureRequestStatus.failure),
      ],
    );

    blocTest<FeatureRequestCubit, FeatureRequestState>(
      'submit emits failure + addError when the service throws',
      build: () => FeatureRequestCubit(
        submitFeatureRequest: buildSubmit(throwError: StateError('boom')),
      ),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        usefulness: '',
        whenToUse: '',
      ),
      expect: () => [
        const FeatureRequestState(status: FeatureRequestStatus.submitting),
        const FeatureRequestState(status: FeatureRequestStatus.failure),
      ],
      errors: () => [isA<StateError>()],
    );
  });
}
