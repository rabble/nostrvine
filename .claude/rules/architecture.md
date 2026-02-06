# Architecture

Layered architecture is used to build highly scalable, maintainable, and testable apps. The architecture consists of four layers: the data layer, the repository layer, the business logic layer, and the presentation layer. Each layer has a single responsibility and there are clear boundaries between each one.

Benefits:
- Each layer can be developed independently by different teams without impacting other layers
- Testing is simplified since only one layer needs to be mocked
- A structured approach clarifies component ownership, streamlining development and code reviews

## The Flow

```
UI (Presentation) → BLoC (Business Logic) → Repository → Client (Data)
```

## Layers

### Data Layer (Client)

This is the lowest layer of the stack. It is the layer that is closest to the retrieval of data.

**Responsibility**: Retrieving raw data from external sources and making it available to the repository layer. Examples include:
- SQLite database
- Local storage / Shared Preferences
- RESTful APIs
- GPS, battery data, file system

**Key Rule**: The data layer should be free of any specific domain or business logic. Packages within the data layer could be plugged into unrelated projects that need to retrieve data from the same sources.

### Repository Layer

This compositional layer composes one or more data clients and applies "business rules" to the data. A separate repository is created for each domain (e.g., user repository, weather repository).

**Responsibility**: Fetching data from one or more data sources, applying domain specific logic to that raw data, and providing it to the business logic layer.

**Key Rules**:
- Should not import any Flutter dependencies
- Should not be dependent on other repositories
- This layer can be considered the "product" layer - the business/product owner determines the rules for how to combine data from one or more data providers

### Business Logic Layer (BLoC)

This layer composes one or more repositories and contains logic for how to surface the business rules via a specific feature or use-case.

**Responsibility**: Implements the bloc library, retrieves data from the repository layer, and provides a new state to the presentation layer.

**Key Rules**:
- Should have no dependency on the Flutter SDK
- Should not have direct dependencies on other business logic components
- This layer can be considered the "feature" layer - design and product determine the rules for how a particular feature will function

### Presentation Layer (UI)

The presentation layer is the top layer in the stack. It is the UI layer of the app where we use Flutter to "paint pixels" on the screen.

**Responsibility**: Building widgets and managing the widget's lifecycle. Requests updates from the business logic layer to provide it with a new state to update the widget with the correct data.

**Key Rule**: No business logic should exist in this layer. The presentation layer should only interact with the business logic layer.

## Project Organization

The presentation layer and state management live in the project's `lib` folder. The data and repository layers will live as separate packages within the project's `packages` folder.

```
my_app/
├── lib/
│   └── login/
│       ├── bloc/
│       │   ├── login_bloc.dart
│       │   ├── login_event.dart
│       │   └── login_state.dart
│       └── view/
│           ├── login_page.dart
│           └── view.dart
├── packages/
│   ├── user_repository/
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── models/
│   │   │   │   │   ├── models.dart
│   │   │   │   │   └── user.dart
│   │   │   │   └── user_repository.dart
│   │   │   └── user_repository.dart
│   │   └── test/
│   │       ├── models/
│   │       │   └── user_test.dart
│   │       └── user_repository_test.dart
│   └── api_client/
│       ├── lib/
│       │   ├── src/
│       │   │   └── api_client.dart
│       │   └── api_client.dart
│       └── test/
│           └── api_client_test.dart
└── test/
    └── login/
        ├── bloc/
        │   ├── login_bloc_test.dart
        │   ├── login_event_test.dart
        │   └── login_state_test.dart
        └── view/
            └── login_page_test.dart
```

Each layer abstracts the underlying layers' implementation details. Avoid indirect dependencies between layers. The implementation details should not leak between the layers.

## Dependency Graph

Data should only flow from the bottom up, and a layer can only access the layer directly beneath it.

**Good Example**:
```dart
// UI → BLoC → Repository → Client (correct flow)

class LoginPage extends StatelessWidget {
  // ...
  LoginButton(
    onPressed: () => context.read<LoginBloc>().add(const LoginSubmitted()),
  )
  // ...
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      await _userRepository.logIn(state.email, state.password);
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}

class UserRepository {
  const UserRepository(this.apiClient);
  final ApiClient apiClient;
  final String loginUrl = '/login';

  Future<void> logIn(String email, String password) {
    await apiClient.makeRequest(
      url: loginUrl,
      data: {'email': email, 'password': password},
    );
  }
}
```

**Bad Example** (API details leak into BLoC):
```dart
// BLoC directly accesses ApiClient - WRONG!

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final String loginUrl = '/login';  // API detail leaked!

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      await apiClient.makeRequest(  // Direct client access - WRONG!
        url: loginUrl,
        data: {'email': state.email, 'password': state.password},
      );
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}
```

In the bad example, the API implementation details are leaked and made known to the bloc. The API's login url and request information should only be known to the `UserRepository`. If the `ApiClient` ever changes, every bloc that relies on the `ApiClient` will need to be updated and retested.

---

## Dependency Injection

**Primary Method**: Constructor injection

Benefits:
- Enhances testability and clarity
- Makes dependencies explicit
- Facilitates mocking in tests

```dart
// Good - dependencies injected via constructor
class UserRepository {
  UserRepository(this._apiClient, this._database);

  final ApiClient _apiClient;
  final Database _database;
}

// Bad - hidden dependencies, hard to test
class UserRepository {
  final apiClient = ApiClient(); // Hard to test
  final database = Database();   // Hidden dependencies
}
```

---

# Barrel Files

When building a package, a feature, or an API, we create a folder structure with source code inside. Barrel files help avoid long and messy import sections and make refactoring easier.

## What Are Barrel Files?

Barrel files are responsible for exporting other public facing files that should be made available to the rest of the app.

**Recommendation**: Create one barrel file per folder, exporting all files from that folder that could be required elsewhere. Also have a top level barrel file to export the package as a whole.

## Package Structure with Barrel Files

```
my_package/
├── lib/
│   ├── src/
│   │   ├── models/
│   │   │   ├── model_1.dart
│   │   │   ├── model_2.dart
│   │   │   └── models.dart        # barrel file
│   │   └── widgets/
│   │       ├── widget_1.dart
│   │       ├── widget_2.dart
│   │       └── widgets.dart       # barrel file
│   └── my_package.dart            # top-level barrel file
├── test/
└── pubspec.yaml
```

## Feature Structure with Barrel Files

```
my_feature/
├── bloc/
│   ├── feature_bloc.dart
│   ├── feature_event.dart
│   └── feature_state.dart
├── view/
│   ├── feature_page.dart
│   ├── feature_view.dart
│   └── view.dart                  # barrel file
└── my_feature.dart                # feature barrel file
```

## Barrel File Contents

`models.dart`:
```dart
export 'model_1.dart';
export 'model_2.dart';
```

`widgets.dart`:
```dart
export 'widget_1.dart';
export 'widget_2.dart';
```

`my_package.dart`:
```dart
export 'src/models/models.dart';
export 'src/widgets/widgets.dart';
```

**Note**: Only export files intended for public use. If `model_1.dart` is only used internally by `model_2.dart`, don't export it in the barrel file.

## BLoC and Barrel Files

By convention, blocs are broken into separate files (events, states, and the bloc itself). We don't add an extra barrel file since `feature_bloc.dart` works as one, thanks to the `part of` directives.

```
bloc/
├── feature_bloc.dart    # acts as barrel via part/part of
├── feature_event.dart
└── feature_state.dart
```
