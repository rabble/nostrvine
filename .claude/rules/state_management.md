# State Management

## Migration Policy

> **New features**: Use `flutter_bloc` following the layered architecture (UI → BLoC → Repository → Client)
>
> **Existing code**: Riverpod is used for legacy code maintenance only

---

# BLoC (Primary - New Features)

Use BLoC/Cubit for all new feature development.

## Event Transformers

Since Bloc v.7.2.0, events are handled concurrently by default. This allows event handler instances to execute simultaneously but provides no guarantees regarding the order of handler completion.

**Warning**: Concurrent event handling can cause race conditions when the result of operations varies with their order of execution.

### Registering Event Transformers

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc() : super(MyState()) {
    on<MyEvent>(
      _onEvent,
      transformer: sequential(),
    );
    on<MySecondEvent>(
      _onSecondEvent,
      transformer: droppable(),
    );
  }
}
```

**Note**: Event transformers are only applied within the bucket they are specified in. Events of the same type are processed according to their transformer, while different event types are processed concurrently.

### Transformer Types

Use the `bloc_concurrency` package for these transformers:

| Transformer | Behavior | Use Case |
|-------------|----------|----------|
| `concurrent` | Default. Events handled simultaneously | Independent operations |
| `sequential` | FIFO order, one at a time | Operations that depend on previous state |
| `droppable` | Discards events while processing | Prevent duplicate API calls |
| `restartable` | Cancels previous, processes latest | Search/typeahead, latest value matters |

### Sequential Example (Prevent Race Conditions)

```dart
class MoneyBloc extends Bloc<MoneyEvent, MoneyState> {
  MoneyBloc() : super(MoneyState()) {
    // Use sequential to prevent race conditions!
    on<ChangeBalance>(_onChangeBalance, transformer: sequential());
  }

  Future<void> _onChangeBalance(
    ChangeBalance event,
    Emitter<MoneyState> emit,
  ) async {
    final balance = await api.readBalance();
    await api.setBalance(balance + event.add);
  }
}
```

### Droppable Example (Prevent Duplicate Calls)

```dart
class SayHiBloc extends Bloc<SayHiEvent, SayHiState> {
  SayHiBloc() : super(SayHiState()) {
    on<SayHello>(_onSayHello, transformer: droppable());
  }

  Future<void> _onSayHello(SayHello event, Emitter<SayHiState> emit) async {
    await api.say("Hello!");
  }
}
```

### Restartable Example (Latest Value Wins)

```dart
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchState()) {
    on<SearchQueryChanged>(_onSearch, transformer: restartable());
  }

  Future<void> _onSearch(SearchQueryChanged event, Emitter<SearchState> emit) async {
    final results = await api.search(event.query);
    emit(state.copyWith(results: results));
  }
}
```

### Testing BLoCs with Event Order

When testing, ensure predictable event order:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) async {
    bloc.add(ChangeValue(add: 1));
    await Future<void>.delayed(Duration.zero); // Ensure first completes
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

---

## State Handling: Enum vs Sealed Classes

Choose based on whether you need to persist data across state changes.

### When to Use Enum Status (Persist Data)

Use a **single class with an enum status** when:
- Form data is updated step by step
- State has several values loaded independently
- You need to preserve previously emitted data

```dart
enum CreateAccountStatus { initial, loading, success, failure }

class CreateAccountState extends Equatable {
  const CreateAccountState({
    this.status = CreateAccountStatus.initial,
    this.name,
    this.surname,
    this.email,
  });

  final CreateAccountStatus status;
  final String? name;
  final String? surname;
  final String? email;

  CreateAccountState copyWith({
    CreateAccountStatus? status,
    String? name,
    String? surname,
    String? email,
  }) {
    return CreateAccountState(
      status: status ?? this.status,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
    );
  }

  bool get isValid => name?.isNotEmpty == true
      && surname?.isNotEmpty == true
      && email?.isNotEmpty == true;

  @override
  List<Object?> get props => [status, name, surname, email];
}
```

**Cubit usage:**
```dart
class CreateAccountCubit extends Cubit<CreateAccountState> {
  CreateAccountCubit() : super(const CreateAccountState());

  void updateName(String name) {
    emit(state.copyWith(name: name)); // Preserves other data
  }

  Future<void> createAccount() async {
    emit(state.copyWith(status: CreateAccountStatus.loading));
    try {
      if (state.isValid) {
        emit(state.copyWith(status: CreateAccountStatus.success));
      }
    } catch (e, s) {
      addError(e, s);
      emit(state.copyWith(status: CreateAccountStatus.failure));
    }
  }
}
```

**UI consumption:**
```dart
BlocListener<CreateAccountCubit, CreateAccountState>(
  listener: (context, state) {
    if (state.status == CreateAccountStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  },
  child: CreateAccountFormView(),
)
```

### When to Use Sealed Classes (Fresh State)

Use **sealed classes** when:
- Data fetching is a one-time operation
- You don't need to preserve data across state changes
- Each state has isolated, non-nullable properties

```dart
sealed class ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileSuccess extends ProfileState {
  ProfileSuccess(this.profile);
  final Profile profile;
}

class ProfileFailure extends ProfileState {
  ProfileFailure(this.errorMessage);
  final String errorMessage;
}
```

**Cubit usage:**
```dart
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileLoading()) {
    getProfileDetails();
  }

  Future<void> getProfileDetails() async {
    try {
      final data = await repository.getProfile();
      emit(ProfileSuccess(data));
    } catch (e) {
      emit(ProfileFailure('Could not load profile'));
    }
  }
}
```

**UI consumption with exhaustive switch:**
```dart
BlocBuilder<ProfileCubit, ProfileState>(
  builder: (context, state) {
    return switch (state) {
      ProfileLoading() => const CircularProgressIndicator(),
      ProfileSuccess(:final profile) => ProfileView(profile),
      ProfileFailure(:final errorMessage) => Text(errorMessage),
    };
  },
)
```

### Sharing Properties Across Sealed States

```dart
sealed class ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileSuccess extends ProfileState {
  ProfileSuccess(this.profile);
  final Profile profile;
}

class ProfileEditing extends ProfileState {
  ProfileEditing(this.profile);
  final Profile profile;
}

class ProfileFailure extends ProfileState {
  ProfileFailure(this.errorMessage);
  final String errorMessage;
}

// In Cubit - handle shared properties:
Future<void> editName(String newName) async {
  switch (state) {
    case ProfileSuccess(profile: final prof):
    case ProfileEditing(profile: final prof):
      final newProfile = prof.copyWith(name: newName);
      emit(ProfileSuccess(newProfile));
    case ProfileLoading():
    case ProfileFailure():
      return;
  }
}

// In UI - pattern match shared properties:
return switch (state) {
  ProfileLoading() => const CircularProgressIndicator(),
  ProfileSuccess(profile: final prof) ||
  ProfileEditing(profile: final prof) => ProfileView(prof),
  ProfileFailure(errorMessage: final message) => Text(message),
};
```

---

# Riverpod (Legacy - Existing Code)

> **Note**: These rules are for maintaining existing Riverpod code only. Use BLoC for new features.

## Using Ref

1. `Ref` is essential for accessing the provider system, reading/watching other providers, managing lifecycles
2. In functional providers, obtain `Ref` as a parameter; in class-based providers, access it as a property of the Notifier
3. In widgets, use `WidgetRef` (a subtype of `Ref`) to interact with providers

### Ref Methods

| Method | Use Case |
|--------|----------|
| `ref.watch` | Reactive listening, rebuilds on change |
| `ref.read` | One-time access (non-reactive) |
| `ref.listen` | Imperative subscriptions |
| `ref.onDispose` | Cleanup resources |

```dart
// Functional provider
@riverpod
int example(Ref ref) {
  final value = ref.watch(otherProvider);
  return value * 2;
}

// Widget consumption
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myProvider);
    return Text('$value');
  }
}
```

## Key Rules

1. **Prefer `ref.watch`** for reactive logic that auto-recomputes
2. **Avoid `ref.watch` in imperative code** (callbacks, Notifier methods) - only use during build phase
3. **Use `ref.read` sparingly** - only when you cannot use `ref.watch`
4. **Always enable `autoDispose` for parameterized providers** to prevent memory leaks
5. **Use `ConsumerWidget`/`ConsumerStatefulWidget`** over raw StatelessWidget when accessing providers

## Auto Dispose

```dart
// Code generation - auto dispose by default
@riverpod
Future<Data> fetchData(Ref ref) async {
  return api.getData();
}

// Opt out of auto dispose
@Riverpod(keepAlive: true)
Future<Data> persistentData(Ref ref) async {
  return api.getData();
}
```

## Passing Arguments (Families)

```dart
@riverpod
Future<User> user(Ref ref, String id) async {
  return api.getUser(id);
}

// Consumption
final user = ref.watch(userProvider('user-123'));
```

## Side Effects in Notifiers

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    return repository.getTodos();
  }

  Future<void> addTodo(Todo todo) async {
    await repository.addTodo(todo);
    ref.invalidateSelf(); // Refresh the list
  }
}
```

## Testing

```dart
// Unit test
final container = ProviderContainer();
addTearDown(container.dispose);
expect(container.read(myProvider), equals('value'));

// Widget test
await tester.pumpWidget(
  ProviderScope(
    overrides: [myProvider.overrideWithValue('mock')],
    child: MyWidget(),
  ),
);
```
