# Invite Sharing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users view, copy, and share invite codes granted by the server, with a synthetic notification card in the notifications tab.

**Architecture:** New `InviteStatusCubit` fetches `GET /v1/invite-status` from `invite.divine.video`. New invites screen in settings displays codes with copy/share actions. Notifications tab injects a synthetic invite card when unclaimed codes exist.

**Tech Stack:** flutter_bloc, equatable, share_plus, http, mocktail, bloc_test

**Spec:** `docs/superpowers/specs/2026-04-08-invite-sharing-design.md`

---

## Chunk 1: Models and API Service

### Task 1: Add InviteStatus and InviteCode models

**Files:**
- Modify: `lib/models/invite_models.dart` (append after line 110)
- Test: `test/models/invite_models_test.dart` (create)

- [ ] **Step 1: Write failing tests for InviteCode and InviteStatus**

```dart
// test/models/invite_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/invite_models.dart';

void main() {
  group(InviteCode, () {
    test('fromJson parses unclaimed code', () {
      final json = {
        'code': 'AB23-EF7K',
        'claimed': false,
        'claimedAt': null,
        'claimedBy': null,
      };
      final code = InviteCode.fromJson(json);
      expect(code.code, equals('AB23-EF7K'));
      expect(code.claimed, isFalse);
      expect(code.claimedAt, isNull);
      expect(code.claimedBy, isNull);
    });

    test('fromJson parses claimed code', () {
      final json = {
        'code': 'AB23-EF7K',
        'claimed': true,
        'claimedAt': '2025-01-15T10:30:00Z',
        'claimedBy': 'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
      };
      final code = InviteCode.fromJson(json);
      expect(code.claimed, isTrue);
      expect(code.claimedAt, isNotNull);
      expect(code.claimedBy, equals('aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1'));
    });
  });

  group(InviteStatus, () {
    test('fromJson parses eligible user with codes', () {
      final json = {
        'canInvite': true,
        'remaining': 3,
        'total': 5,
        'codes': [
          {'code': 'AB23-EF7K', 'claimed': false, 'claimedAt': null, 'claimedBy': null},
          {'code': 'HN4P-QR56', 'claimed': true, 'claimedAt': '2025-01-15T10:30:00Z', 'claimedBy': 'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1'},
        ],
      };
      final status = InviteStatus.fromJson(json);
      expect(status.canInvite, isTrue);
      expect(status.remaining, equals(3));
      expect(status.total, equals(5));
      expect(status.codes, hasLength(2));
    });

    test('fromJson parses ineligible user', () {
      final json = {
        'canInvite': false,
        'remaining': 0,
        'total': 0,
        'codes': <Map<String, dynamic>>[],
      };
      final status = InviteStatus.fromJson(json);
      expect(status.canInvite, isFalse);
      expect(status.codes, isEmpty);
    });

    test('unclaimedCodes returns only unclaimed', () {
      final status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 2,
        codes: [
          const InviteCode(code: 'AAAA-BBBB', claimed: false),
          const InviteCode(code: 'CCCC-DDDD', claimed: true, claimedBy: 'abc'),
        ],
      );
      expect(status.unclaimedCodes, hasLength(1));
      expect(status.unclaimedCodes.first.code, equals('AAAA-BBBB'));
    });

    test('hasUnclaimedCodes is true when unclaimed exist', () {
      final status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 1,
        codes: [const InviteCode(code: 'AAAA-BBBB', claimed: false)],
      );
      expect(status.hasUnclaimedCodes, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/models/invite_models_test.dart`
Expected: Compilation error — `InviteCode` and `InviteStatus` not defined.

- [ ] **Step 3: Implement InviteCode and InviteStatus models**

Add `import 'package:equatable/equatable.dart';` at the top of `lib/models/invite_models.dart`, then append:

```dart
class InviteCode extends Equatable {
  const InviteCode({
    required this.code,
    required this.claimed,
    this.claimedAt,
    this.claimedBy,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      code: json['code'] as String? ?? '',
      claimed: json['claimed'] == true,
      claimedAt: json['claimedAt'] != null
          ? DateTime.tryParse(json['claimedAt'] as String)
          : null,
      claimedBy: json['claimedBy'] as String?,
    );
  }

  final String code;
  final bool claimed;
  final DateTime? claimedAt;
  final String? claimedBy;

  @override
  List<Object?> get props => [code, claimed, claimedAt, claimedBy];
}

class InviteStatus extends Equatable {
  const InviteStatus({
    required this.canInvite,
    required this.remaining,
    required this.total,
    required this.codes,
  });

  factory InviteStatus.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['codes'] as List<dynamic>? ?? [];
    return InviteStatus(
      canInvite: json['canInvite'] == true,
      remaining: (json['remaining'] ?? 0) as int,
      total: (json['total'] ?? 0) as int,
      codes: rawCodes
          .cast<Map<String, dynamic>>()
          .map(InviteCode.fromJson)
          .toList(),
    );
  }

  final bool canInvite;
  final int remaining;
  final int total;
  final List<InviteCode> codes;

  List<InviteCode> get unclaimedCodes =>
      codes.where((c) => !c.claimed).toList();

  bool get hasUnclaimedCodes => codes.any((c) => !c.claimed);

  @override
  List<Object?> get props => [canInvite, remaining, total, codes];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/models/invite_models_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/models/invite_models.dart test/models/invite_models_test.dart
git commit -m "feat(invite): add InviteStatus and InviteCode models"
```

---

### Task 2: Add getInviteStatus and generateInvite to InviteApiService

**Files:**
- Modify: `lib/services/invite_api_service.dart` (add methods before `dispose()` at line 379)
- Test: `test/services/invite_api_service_test.dart` (create or extend)

- [ ] **Step 1: Write failing tests for getInviteStatus**

```dart
// test/services/invite_api_service_invite_status_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/invite_api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('getInviteStatus', () {
    late _MockNip98AuthService mockAuthService;

    setUp(() {
      mockAuthService = _MockNip98AuthService();
      when(() => mockAuthService.canCreateTokens).thenReturn(true);
      when(
        () => mockAuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('returns InviteStatus on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, contains('/v1/invite-status'));
        return http.Response(
          jsonEncode({
            'canInvite': true,
            'remaining': 3,
            'total': 5,
            'codes': [
              {'code': 'AB23-EF7K', 'claimed': false},
            ],
          }),
          200,
        );
      });

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      final result = await service.getInviteStatus();
      expect(result.canInvite, isTrue);
      expect(result.remaining, equals(3));
      expect(result.codes, hasLength(1));
    });

    test('throws ApiException on non-200', () async {
      final mockClient = MockClient(
        (request) async => http.Response('{"error": "Unauthorized"}', 401),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      expect(() => service.getInviteStatus(), throwsA(isA<Exception>()));
    });
  });

  group('generateInvite', () {
    late _MockNip98AuthService mockAuthService;

    setUp(() {
      mockAuthService = _MockNip98AuthService();
      when(() => mockAuthService.canCreateTokens).thenReturn(true);
      when(
        () => mockAuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('returns code and remaining on 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, contains('/v1/generate-invite'));
        return http.Response(
          jsonEncode({'code': 'WX56-3MKT', 'remaining': 4}),
          201,
        );
      });

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      final result = await service.generateInvite();
      expect(result.code, equals('WX56-3MKT'));
      expect(result.remaining, equals(4));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/services/invite_api_service_invite_status_test.dart`
Expected: Compilation error — `getInviteStatus` and `generateInvite` not defined.

- [ ] **Step 3: Add GenerateInviteResult model to invite_models.dart**

Append to `lib/models/invite_models.dart`:

```dart
class GenerateInviteResult extends Equatable {
  const GenerateInviteResult({
    required this.code,
    required this.remaining,
  });

  factory GenerateInviteResult.fromJson(Map<String, dynamic> json) {
    return GenerateInviteResult(
      code: json['code'] as String? ?? '',
      remaining: (json['remaining'] ?? 0) as int,
    );
  }

  final String code;
  final int remaining;

  @override
  List<Object?> get props => [code, remaining];
}
```

- [ ] **Step 4: Add getInviteStatus and generateInvite methods to InviteApiService**

Insert before `dispose()` in `lib/services/invite_api_service.dart`:

```dart
  Future<InviteStatus> getInviteStatus() async {
    final uri = Uri.parse('$_baseUrl/v1/invite-status');

    try {
      final response = await _client
          .get(uri, headers: await _headers(url: uri.toString(), requiresAuth: true))
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to fetch invite status',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return InviteStatus.fromJson(json);
    } on TimeoutException {
      throw const ApiException('Invite status request timed out');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Failed to fetch invite status: $error');
    }
  }

  Future<GenerateInviteResult> generateInvite() async {
    final uri = Uri.parse('$_baseUrl/v1/generate-invite');

    try {
      final response = await _client
          .post(
            uri,
            headers: await _headers(
              url: uri.toString(),
              method: HttpMethod.post,
              requiresAuth: true,
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to generate invite code',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GenerateInviteResult.fromJson(json);
    } on TimeoutException {
      throw const ApiException('Generate invite request timed out');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Failed to generate invite code: $error');
    }
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd mobile && flutter test test/services/invite_api_service_invite_status_test.dart`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/models/invite_models.dart lib/services/invite_api_service.dart test/services/invite_api_service_invite_status_test.dart
git commit -m "feat(invite): add getInviteStatus and generateInvite to InviteApiService"
```

---

## Chunk 2: InviteStatusCubit

### Task 3: Create InviteStatusCubit with state

**Files:**
- Create: `lib/blocs/invite_status/invite_status_cubit.dart`
- Create: `lib/blocs/invite_status/invite_status_state.dart` (as `part of`)
- Test: `test/blocs/invite_status/invite_status_cubit_test.dart`

Follow the exact pattern from `lib/blocs/settings_account/settings_account_cubit.dart`.

- [ ] **Step 1: Write failing tests**

```dart
// test/blocs/invite_status/invite_status_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

void main() {
  group(InviteStatusCubit, () {
    late _MockInviteApiService mockInviteApiService;

    final testStatus = InviteStatus(
      canInvite: true,
      remaining: 3,
      total: 5,
      codes: [
        const InviteCode(code: 'AB23-EF7K', claimed: false),
        const InviteCode(
          code: 'HN4P-QR56',
          claimed: true,
          claimedBy: 'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
        ),
      ],
    );

    setUp(() {
      mockInviteApiService = _MockInviteApiService();
    });

    InviteStatusCubit buildCubit() => InviteStatusCubit(
      inviteApiService: mockInviteApiService,
    );

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(InviteStatusLoadingStatus.initial));
      expect(cubit.state.inviteStatus, isNull);
    });

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then loaded with invite status',
      setUp: () {
        when(() => mockInviteApiService.getInviteStatus())
            .thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
        ),
      ],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then error on failure',
      setUp: () {
        when(() => mockInviteApiService.getInviteStatus())
            .thenThrow(Exception('network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(status: InviteStatusLoadingStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load does not re-fetch if already loading',
      setUp: () {
        when(() => mockInviteApiService.getInviteStatus())
            .thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.loading,
      ),
      act: (cubit) => cubit.load(),
      expect: () => <InviteStatusState>[],
      verify: (_) {
        verifyNever(() => mockInviteApiService.getInviteStatus());
      },
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/blocs/invite_status/invite_status_cubit_test.dart`
Expected: Compilation error — files don't exist.

- [ ] **Step 3: Implement InviteStatusCubit and state**

Create `lib/blocs/invite_status/invite_status_cubit.dart`:

```dart
// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/invite_api_service.dart';

part 'invite_status_state.dart';

class InviteStatusCubit extends Cubit<InviteStatusState> {
  InviteStatusCubit({
    required InviteApiService inviteApiService,
  }) : _inviteApiService = inviteApiService,
       super(const InviteStatusState());

  final InviteApiService _inviteApiService;

  Future<void> load() async {
    if (state.status == InviteStatusLoadingStatus.loading) return;

    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiService.getInviteStatus();
      emit(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: InviteStatusLoadingStatus.error));
    }
  }
}
```

Create `lib/blocs/invite_status/invite_status_state.dart`:

```dart
part of 'invite_status_cubit.dart';

enum InviteStatusLoadingStatus { initial, loading, loaded, error }

class InviteStatusState extends Equatable {
  const InviteStatusState({
    this.status = InviteStatusLoadingStatus.initial,
    this.inviteStatus,
  });

  final InviteStatusLoadingStatus status;
  final InviteStatus? inviteStatus;

  bool get hasUnclaimedCodes =>
      inviteStatus?.hasUnclaimedCodes ?? false;

  int get unclaimedCount =>
      inviteStatus?.unclaimedCodes.length ?? 0;

  InviteStatusState copyWith({
    InviteStatusLoadingStatus? status,
    InviteStatus? inviteStatus,
  }) {
    return InviteStatusState(
      status: status ?? this.status,
      inviteStatus: inviteStatus ?? this.inviteStatus,
    );
  }

  @override
  List<Object?> get props => [status, inviteStatus];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/blocs/invite_status/invite_status_cubit_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/blocs/invite_status/ test/blocs/invite_status/
git commit -m "feat(invite): add InviteStatusCubit for fetching invite status"
```

---

## Chunk 3: Invites Screen

### Task 4: Create the InvitesScreen with Page/View pattern

**Files:**
- Create: `lib/screens/settings/invites_screen.dart`
- Modify: `lib/router/app_router.dart` (add route)
- Test: `test/screens/settings/invites_screen_test.dart`

**Context:**
- Follow the Page/View pattern from `settings_screen.dart` — Page creates cubit, View renders UI
- Settings sub-routes are flat peers (not nested children), e.g. `/invites` like `/notification-settings`
- Use `ClipboardUtils.copy()` from `lib/utils/clipboard_utils.dart` for clipboard
- Use `SharePlus.instance.share()` from `share_plus` for native share sheet
- Use `VineTheme` colors and fonts throughout (dark mode only)

- [ ] **Step 1: Write failing widget tests**

```dart
// test/screens/settings/invites_screen_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/screens/settings/invites_screen.dart';

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

void main() {
  group(InvitesView, () {
    late _MockInviteStatusCubit mockCubit;

    setUp(() {
      mockCubit = _MockInviteStatusCubit();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockCubit,
          child: const InvitesView(),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when loading', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('empty state when no invites', (tester) async {
        when(() => mockCubit.state).thenReturn(
          InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: const InviteStatus(
              canInvite: false,
              remaining: 0,
              total: 0,
              codes: [],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('No invites available right now'), findsOneWidget);
      });

      testWidgets('invite codes when available', (tester) async {
        when(() => mockCubit.state).thenReturn(
          InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 2,
              total: 3,
              codes: [
                const InviteCode(code: 'AB23-EF7K', claimed: false),
                const InviteCode(code: 'HN4P-QR56', claimed: false),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('AB23-EF7K'), findsOneWidget);
        expect(find.text('HN4P-QR56'), findsOneWidget);
      });

      testWidgets('retry button on error', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping retry calls load', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        when(() => mockCubit.load()).thenAnswer((_) async {});
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Retry'));
        verify(() => mockCubit.load()).called(1);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/settings/invites_screen_test.dart`
Expected: Compilation error — `InvitesView` not defined.

- [ ] **Step 3: Implement InvitesScreen (Page + View)**

Create `lib/screens/settings/invites_screen.dart`:

```dart
// ABOUTME: Settings screen for viewing and sharing invite codes.
// ABOUTME: Page creates InviteStatusCubit; View renders code list with copy/share.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/invite_api_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:share_plus/share_plus.dart';

class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  static const routeName = 'invites';
  static const path = '/invites';

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  late final InviteStatusCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = InviteStatusCubit(
      inviteApiService: InviteApiService(
        authService: ref.read(nip98AuthServiceProvider),
      ),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: VineTheme.navGreen,
          title: const Text('Invite Friends'),
        ),
        body: const InvitesView(),
      ),
    );
  }
}

@visibleForTesting
class InvitesView extends StatelessWidget {
  const InvitesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteStatusCubit, InviteStatusState>(
      builder: (context, state) {
        return switch (state.status) {
          InviteStatusLoadingStatus.initial ||
          InviteStatusLoadingStatus.loading =>
            const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          InviteStatusLoadingStatus.error => _ErrorView(
              onRetry: () => context.read<InviteStatusCubit>().load(),
            ),
          InviteStatusLoadingStatus.loaded => _LoadedView(
              inviteStatus: state.inviteStatus!,
            ),
        };
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.inviteStatus});

  final InviteStatus inviteStatus;

  @override
  Widget build(BuildContext context) {
    final unclaimed = inviteStatus.unclaimedCodes;
    final claimed = inviteStatus.codes.where((c) => c.claimed).toList();

    if (unclaimed.isEmpty && claimed.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No invites available right now',
            style: TextStyle(fontSize: 16, color: VineTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (unclaimed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Share diVine with people you know',
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ),
          ...unclaimed.map((code) => _InviteCodeCard(code: code)),
          const SizedBox(height: 24),
        ],
        if (claimed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Used invites',
              style: VineTheme.titleSmallFont(color: VineTheme.secondaryText),
            ),
          ),
          ...claimed.map((code) => _ClaimedCodeRow(code: code)),
        ],
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final InviteCode code;

  String get _shareMessage =>
      'Join me on diVine! Use invite code ${code.code} to get started:\n'
      'https://divine.video/invite/${code.code}';

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code.code,
                style: VineTheme.titleLargeFont(color: VineTheme.whiteText),
              ),
            ),
            IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.copy,
                color: VineTheme.vineGreen,
              ),
              tooltip: 'Copy invite',
              onPressed: () =>
                  ClipboardUtils.copy(context, _shareMessage, message: 'Invite copied!'),
            ),
            IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.share,
                color: VineTheme.vineGreen,
              ),
              tooltip: 'Share invite',
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: _shareMessage,
                  subject: 'Join me on diVine',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedCodeRow extends StatelessWidget {
  const _ClaimedCodeRow({required this.code});

  final InviteCode code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code.code,
              style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
            ),
          ),
          const DivineIcon(
            icon: DivineIconName.check,
            color: VineTheme.vineGreen,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Claimed',
            style: VineTheme.labelSmallFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Could not load invites',
            style: TextStyle(fontSize: 16, color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add route to app_router.dart**

Add after the settings route (around line 616) in `lib/router/app_router.dart`:

```dart
GoRoute(
  path: InvitesScreen.path,
  name: InvitesScreen.routeName,
  builder: (_, _) => const InvitesScreen(),
),
```

Add import: `import 'package:openvine/screens/settings/invites_screen.dart';`

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/settings/invites_screen_test.dart`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/invites_screen.dart lib/router/app_router.dart test/screens/settings/invites_screen_test.dart
git commit -m "feat(invite): add InvitesScreen with code list, copy, and share"
```

---

## Chunk 4: Settings Account Header Integration

### Task 5: Add Invites row to settings account header

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart` (in `_AccountHeader`, around line 318)
- Modify: `test/screens/settings/settings_screen_test.dart` (add tests)

**Context:**
- The `_AccountHeader` widget is at line 297. Its `Column` children are at line 318.
- Add an invites row between `_AccountHeaderProfile` and the switch-account button.
- The cubit is created in `_SettingsScreenState.initState()` alongside `_accountCubit`.
- The invites row taps to `context.push(InvitesScreen.path)`.

- [ ] **Step 1: Write failing test for the invites row**

Add to the settings screen test file:

```dart
testWidgets('renders invites row in account header', (tester) async {
  // Set up BlocProvider with InviteStatusCubit in loaded state
  // with unclaimed codes, verify "Invites" text and badge appear
});

testWidgets('hides invites row when no invites available', (tester) async {
  // Set up with canInvite: false, verify no "Invites" text
});

testWidgets('navigates to invites screen on tap', (tester) async {
  // Tap invites row, verify context.push called with InvitesScreen.path
});
```

The exact test setup depends on the existing test structure for `settings_screen_test.dart`. Read it and follow the same mock/provider pattern.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/settings/settings_screen_test.dart`

- [ ] **Step 3: Add InviteStatusCubit to settings screen**

In `_SettingsScreenState.initState()` (line 58), add:

```dart
_inviteStatusCubit = InviteStatusCubit(
  inviteApiService: InviteApiService(
    authService: ref.read(nip98AuthServiceProvider),
  ),
)..load();
```

Add field: `late final InviteStatusCubit _inviteStatusCubit;`
In `dispose()`: add `_inviteStatusCubit.close();`

Wrap the existing `BlocProvider.value` with a `MultiBlocProvider` or add a second `BlocProvider` around the scaffold.

- [ ] **Step 4: Add invites row to _AccountHeader**

In the `_AccountHeader` widget's `Column` children (line 318), add between `_AccountHeaderProfile` and the switch-account `Semantics` widget:

```dart
BlocBuilder<InviteStatusCubit, InviteStatusState>(
  builder: (context, inviteState) {
    if (!inviteState.hasUnclaimedCodes) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: 'Invites',
      child: InkWell(
        onTap: () => context.push(InvitesScreen.path),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VineTheme.outlineMuted,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const DivineIcon(
                icon: DivineIconName.shareNetwork,
                color: VineTheme.vineGreen,
              ),
              Text(
                'Invites',
                style: VineTheme.titleMediumFont(
                  color: VineTheme.vineGreen,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${inviteState.unclaimedCount}',
                  style: VineTheme.labelSmallFont(
                    color: VineTheme.backgroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
),
```

**Note:** `DivineIconName.shareNetwork` is confirmed to exist in the icon enum.

- [ ] **Step 5: Run tests**

Run: `cd mobile && flutter test test/screens/settings/settings_screen_test.dart`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/settings_screen.dart test/screens/settings/settings_screen_test.dart
git commit -m "feat(invite): add invites row to settings account header"
```

---

## Chunk 5: Notifications Tab Integration

### Task 6: Add synthetic invite notification card to notifications tab

**Files:**
- Modify: `lib/screens/notifications_screen.dart` (in `_NotificationTabContent`)
- Test: `test/screens/notifications_screen_test.dart` (add tests)

**Context:**
- The `_NotificationTabContent` widget builds a `ListView.builder` at line 356.
- The "All" tab uses `filter: null` (line 154).
- The synthetic card should only show on the "All" tab (`filter == null`).
- The `InviteStatusCubit` must be provided above `NotificationsScreen` in the widget tree (at app level or shell level).
- When the notifications tab opens, call `cubit.load()` to check invite status.

- [ ] **Step 1: Write failing test for synthetic invite card**

```dart
testWidgets('renders invite card when unclaimed codes exist on All tab', (tester) async {
  // Provide InviteStatusCubit with loaded state containing unclaimed codes
  // Render _NotificationTabContent with filter: null
  // Expect to find invite card text
});

testWidgets('does not render invite card on filtered tabs', (tester) async {
  // Render _NotificationTabContent with filter: NotificationType.like
  // Even with unclaimed codes, should not show invite card
});
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Trigger invite status load in notifications screen**

In `_NotificationsScreenState.initState()`, after the existing `_bootstrapFreshFeed()` call, add:

```dart
// Check invite status when notifications tab opens
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<InviteStatusCubit>().load();
});
```

This requires `InviteStatusCubit` to be provided above `NotificationsScreen` in the widget tree. The cubit should be created at the app shell level (where the bottom tab bar lives) so both settings and notifications can access it.

- [ ] **Step 4: Add synthetic invite card to ListView.builder**

In `_NotificationTabContent.build()`, modify the `ListView.builder` at line 356:

```dart
// Determine if invite card should show
final showInviteCard = widget.filter == null &&
    context.select<InviteStatusCubit, bool>(
      (cubit) => cubit.state.hasUnclaimedCodes,
    );
final inviteCardOffset = showInviteCard ? 1 : 0;
```

Update `itemCount`:
```dart
itemCount: notifications.length + inviteCardOffset + (/* existing loading indicator logic */),
```

In `itemBuilder`, at the top:
```dart
if (showInviteCard && index == 0) {
  return _InviteNotificationCard(
    count: context.read<InviteStatusCubit>().state.unclaimedCount,
  );
}
final adjustedIndex = index - inviteCardOffset;
// Replace all subsequent uses of `index` with `adjustedIndex`
```

- [ ] **Step 5: Create _InviteNotificationCard widget**

Add to `notifications_screen.dart`:

```dart
class _InviteNotificationCard extends StatelessWidget {
  const _InviteNotificationCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? 'You have 1 invite to share with a friend!'
        : 'You have $count invites to share with friends!';

    return InkWell(
      onTap: () => context.push(InvitesScreen.path),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: VineTheme.cardBackground,
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: VineTheme.vineGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: VineTheme.backgroundColor,
                size: 24,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
              ),
            ),
            const DivineIcon(
              icon: DivineIconName.caretRight,
              color: VineTheme.lightText,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests**

Run: `cd mobile && flutter test test/screens/notifications_screen_test.dart`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/notifications_screen.dart test/screens/notifications_screen_test.dart
git commit -m "feat(invite): add synthetic invite card to notifications tab"
```

---

## Chunk 6: App-Level Cubit Wiring

### Task 7: Provide InviteStatusCubit at app/shell level

**Files:**
- Modify: The widget that wraps both settings and notifications (likely `app_shell.dart` or the app's `MultiBlocProvider` in `main.dart` or the shell route builder)

**Context:**
- Both settings and notifications need to read `InviteStatusCubit`.
- Find where the app shell / bottom navigation bar is built. That's where the cubit should be provided.
- Check: `grep -r 'AppShell\|ShellRoute\|ScaffoldWithNavBar' lib/` to find the shell widget.
- The cubit needs `InviteApiService` which needs `Nip98AuthService`. Both should be available from existing Riverpod providers.

- [ ] **Step 1: Locate the shell widget**

Run: `grep -rn 'ShellRoute\|AppShell\|ScaffoldWithNavBar' lib/router/ lib/widgets/`

- [ ] **Step 2: Add InviteStatusCubit as a BlocProvider in the shell**

Wrap the shell's child with:
```dart
BlocProvider(
  create: (context) => InviteStatusCubit(
    inviteApiService: InviteApiService(
      authService: /* get Nip98AuthService from Riverpod or context */,
    ),
  ),
  child: existingChild,
)
```

- [ ] **Step 3: Remove the duplicate cubit creation from InvitesScreen**

Since the cubit now lives at shell level, `InvitesScreen` should read it from context instead of creating its own. Change it to a `StatefulWidget` that calls `load()` in `initState()`:

```dart
class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  static const routeName = 'invites';
  static const path = '/invites';

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger a refresh each time the screen is opened
    context.read<InviteStatusCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.navGreen,
        title: const Text('Invite Friends'),
      ),
      body: const InvitesView(),
    );
  }
}
```

Also remove the duplicate cubit creation from `_SettingsScreenState` (Task 5) -- the settings screen should read the shell-level cubit via `context.read<InviteStatusCubit>()` instead.

- [ ] **Step 4: Update tests for new wiring**

- [ ] **Step 5: Run all affected tests**

Run: `cd mobile && flutter test test/screens/settings/ test/screens/notifications_screen_test.dart test/blocs/invite_status/`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/invites_screen.dart lib/screens/settings/settings_screen.dart lib/screens/notifications_screen.dart lib/router/app_shell.dart
git commit -m "feat(invite): wire InviteStatusCubit at app shell level"
```

---

## Chunk 7: Server Prompt & Verification

### Task 8: Write the divine-invite-darshan server prompt

**Files:**
- Create: `docs/superpowers/specs/2026-04-08-invite-darshan-server-prompt.md`

- [ ] **Step 1: Write the server change prompt**

This prompt will be given to the engineer working on the `divine-invite-darshan` Rust/WASM server. It describes the grant-on-read logic for `GET /v1/invite-status`.

Content is already defined in the design spec under "Server Prompt (divine-invite-darshan)". Write it as a standalone document with:
- What endpoint to modify
- The grant-on-read evaluation flow
- Config keys for the policy engine
- Example request/response (unchanged shape)
- What NOT to change (response shape, other endpoints)

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-04-08-invite-darshan-server-prompt.md
git commit -m "docs: add divine-invite-darshan server prompt for grant-on-read"
```

### Task 9: Run full verification

- [ ] **Step 1: Run analyzer**

Run: `cd mobile && flutter analyze lib test`
Expected: No issues.

- [ ] **Step 2: Run all tests**

Run: `cd mobile && flutter test`
Expected: All pass.

- [ ] **Step 3: Run format check**

Run: `cd mobile && dart format --output=none --set-exit-if-changed lib test`
Expected: No formatting issues.

- [ ] **Step 4: Fix any issues found, commit fixes**
