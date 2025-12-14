# Very Good Flutter App Documentation

# Architecture


import { FileTree, TabItem, Tabs } from "@astrojs/starlight/components";
import Diagram from "~/components/diagram.astro";
import architectureDark from "./diagrams/layered_architecture_dark.png";
import architectureLight from "./diagrams/layered_architecture_light.png";

Layered architecture is used at VGV to build highly scalable, maintainable, and testable apps. The architecture consists of four layers: the data layer, the repository layer, the business logic layer, and the presentation layer. Each layer has a single responsibility and there are clear boundaries between each one. We've discovered that a layered architecture significantly enhances the developer experience. Each layer can be developed independently by different teams without impacting other layers. Testing is simplified since only one layer needs to be mocked. Additionally, a structured approach clarifies component ownership, streamlining development and code reviews.

## Layers

### Data Layer

This is the lowest layer of the stack. It is the layer that is closest to the retrieval of data, hence the name.

#### Responsibility

The data layer is responsible for retrieving raw data from external sources and making it available to the [repository layer](#repository-layer). Examples of these external sources include an SQLite database, local storage, Shared Preferences, GPS, battery data, file system, or a RESTful API.

The data layer should be free of any specific domain or business logic. Ideally, packages within the data layer could be plugged into unrelated projects that need to retrieve data from the same sources.

### Repository Layer

This compositional layer composes one or more data clients and applies "business rules" to the data. A separate repository is created for each domain, such as a user repository or a weather repository. Packages in this layer should not import any Flutter dependencies and not be dependent on other repositories.

#### Responsibility

The repository layer is responsible for fetching data from one or more data sources from the data layer, applying domain specific logic to that raw data, and providing it to the business logic layer.

> This layer can be considered the "product" layer. The business/product owner will determine the rules/acceptance criteria for how to combine data from one or more data providers into a unit that brings value to the customer.

### Business Logic Layer

This layer composes one or more repositories and contains logic for how to surface the business rules via a specific feature or use-case. The business logic layer should have no dependency on the Flutter SDK and should not have direct dependencies on other business logic components.

#### Responsibility

The business logic layer is the layer that implements the bloc library, which will retrieve data from the repository layer and provide a new state to the presentation layer.

> This layer can be considered the "feature" layer. Design and product will determine the rules for how a particular feature will function.

### Presentation layer

The presentation layer is the top layer in stack. It is the UI layer of the app where we use Flutter to "paint pixels" on the screen. No business logic should exist in this layer. The presentation layer should only interact with the business logic layer.

#### Responsibility

The presentation layer is the layer that includes the Flutter UI dependencies. It is responsible for building widgets and managing the widget's lifecycle. This layer requests updates from the business logic layer to provide it with a new state to update the widget with the correct data.

> This layer can be considered the "design" layer. Designers will determine the user interface in order to provide the best possible experience for the customer.

## Project organization

The presentation layer and state management live in the project's `lib` folder. The data and repository layers will live as separate packages within the project's `packages` folder.

<FileTree>

- my_app/
  - lib/
    - login/
      - bloc/
        - login_bloc.dart
        - login_event.dart
        - login_state.dart
      - view/
        - login_page.dart
        - view.dart
  - packages/
    - user_repository/
      - lib/
        - src/
          - models/
            - models.dart
            - user.dart
          - user_repository.dart
        - user_repository.dart
      - test/
        - models/
          - user_test.dart
        - user_repository_test.dart
    - api_client/
      - lib/
        - src/
          - api_client.dart
        - api_client.dart
      - test/
        - api_client_test.dart
  - test/
    - login/
      - bloc/
        - login_bloc_test.dart
        - login_event_test.dart
        - login_state_test.dart
      - view/
        - login_page_test.dart

</FileTree>

Each layer abstracts the underlying layers' implementation details. Avoid indirect dependencies between layers. For example, the repository layer shouldn't need to know how the data is fetched in the data layer, and the presentation layer shouldn't directly access values from Shared Preferences. In other words, the implementation details should not leak between the layers. Using layered architecture ensures flexibility, reusability, and testability as the codebase grows.

## Dependency graph

<Diagram
  light={architectureLight}
  dark={architectureDark}
  alt="Good code is a product of competing constraints: minimal, correct, and descriptive."
/>

When using layered architecture, data should only flow from the bottom up, and a layer can only access the layer directly beneath it. For example, the `LoginPage` should never directly access the `ApiClient`, or the `ApiClient` should not be dependent on the `UserRepository`. With this approach, each layer has a specific responsibility and can be tested in isolation.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    class LoginPage extends StatelessWidget {
        ...
        LoginButton(
            onPressed: => context.read<LoginBloc>().add(const LoginSubmitted());
        )
        ...
    }

    class LoginBloc extends Bloc<LoginEvent, LoginState> {
        ...
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
                data: {
                    'email': email,
                    'password': password,
                },
            );
        }
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    class LoginPage extends StatelessWidget {
        ...
        LoginButton(
            onPressed: => context.read<LoginBloc>().add(const LoginSubmitted());
        )
        ...
    }

    class LoginBloc extends Bloc<LoginEvent, LoginState> {
        ...

        final String loginUrl = '/login';

        Future<void> _onLoginSubmitted(
            LoginSubmitted event,
            Emitter<LoginState> emit,
        ) async {
            try {
                await apiClient.makeRequest(
                    url: loginUrl,
                    data: {
                        'email': state.email,
                        'password': state.password,
                    },
            );

            emit(const LoginSuccess());
            } catch (error, stackTrace) {
                addError(error, stackTrace);
                emit(const LoginFailure());
            }
        }
    }
    ```

  </TabItem>
</Tabs>

In this example, the API implementation details are now leaked and made known to the bloc. The API's login url and request information should only be known to the `UserRepository`. Also, the `ApiClient` instance will have to be provided directly to the bloc. If the `ApiClient` ever changes, every bloc that relies on the `ApiClient` will need to be updated and retested.


# Barrel Files


import { FileTree } from "@astrojs/starlight/components";

When building a package, a feature, or an API, we will create a folder structure with all the source code inside. If we stop here and don't export the files that will be required in other places of the app, we will force developers to have a long and messy import section. Furthermore, any refactor that affects file names in one feature will require changes in other places that could be avoided.

For a package, the structure could look something like:

<FileTree>

- my_package/
  - lib/
    - src/
      - models/
        - model_1.dart
        - model_2.dart
      - widgets/
        - widget_1.dart
        - widget_2.dart
  - test/
  - pubspec.yaml

</FileTree>

And for a feature, it could look like:

<FileTree>

- my_feature/
  - bloc/
    - feature_bloc.dart
    - feature_event.dart
    - feature_state.dart
  - view/
    - feature_page.dart
    - feature_view.dart
  - widgets/
    - widget_1.dart
    - widget_2.dart

</FileTree>

In both cases, if we want to use both `widget_1.dart` and `widget_2.dart` in other parts of the app, we will have to import them separately like:

```dart
import 'package:my_package/lib/src/widgets/widget_1';
import 'package:my_package/lib/src/widgets/widget_2';
```

In the case of a refactor, updating all those imports is inefficient. Barrel files help solve this problem.

## Barrel files

Barrel files are responsible for exporting other public facing files that should be made available to the rest of the app.

It is recommended to create one barrel file per folder, exporting all files from that folder that could be required elsewhere. You should also have a top level barrel file to export the package as a whole.

With these changes, let's update the folder structures for both scenarios.

A package with barrel files should look like:

<FileTree>

- my_package/
  - lib/
    - src/
      - models/
        - model_1.dart
        - model_2.dart
        - models.dart
      - widgets/
        - widget_1.dart
        - widget_2.dart
        - widgets.dart
    - my_package.dart
  - test/
  - pubspec.yaml

</FileTree>

And for a feature, it should look like:

<FileTree>

- my_feature/
  - bloc/
    - feature_bloc.dart
    - feature_event.dart
    - feature_state.dart
  - view/
    - feature_page.dart
    - feature_view.dart
    - view.dart
  - my_feature.dart

</FileTree>

Finally let's see what these files contain. Continuing with the package example, we have three barrel files: `models.dart`, `widgets.dart` and `my_package.dart`.

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

:::caution
In this example, we are exporting all files from the folder, but this is not always the case. If the `model_2.dart` uses the `model_1.dart` inside, but `model_1.dart` is not intended to be imported by the public, it should not be exported in the barrel file.
:::

## Bloc and barrel files

By convention, blocs are typically broken into separate files consisting of the events, states, and the bloc itself:

<FileTree>

- bloc/
  - feature_bloc.dart
  - feature_event.dart
  - feature_state.dart

</FileTree>

In this case, we don't add an extra barrel file since the `feature_bloc.dart` file is working as such, thanks to the `part of` directives. You can read more about it in the [bloc documentation][bloc_documentation].

:::tip
When working with barrel files, it might be a bit tedious to export every file manually. There is a handy [VSCode extension][vscode_extension] that allows you to export all files in a folder or export a file by adding it to the barrel file.
:::

[bloc_documentation]: https://bloclibrary.dev/#/flutterlogintutorial?id=authentication-bloc
[vscode_extension]: https://github.com/orestesgaolin/dart-export-index


# CI/CD


CI/CD is the combination of practices from continuous integration and continuous delivery. It automates the software development process, from writing new code to deploying in different environments. With a CI/CD pipeline, development teams can reduce the time it takes to make new releases by automatically testing, building, and/or deploying releases whenever code changes are pushed.

Continuous integration and continuous delivery help teams release faster, leading to faster feature iteration, frequent feedback, and happier users overall. Additionally we ensure the quality by running a set of automated tests before deploying, which minimizes downtime and reduces bugs in production.[^1]

[^1]: [GitLab][ci_cd_gitlab]

## Continuous Integration (CI)

Continuous integration refers to the process of joining the code changes to the main branch of your repository frequently. To ensure this process is seamless and does not cause issues, we automatically run a set of tests and kick off a build before merging. With these practices, errors can be identified and fixed earlier.

When multiple people work on the same codebase, it's important to minimize code conflicts. Merging code frequently can help prevent these issues. Additionally, using automatic testing reduces context switching by immediately alerting developers when an error is found.

:::tip
The advantages of continuous integration rely on a solid set of automatic tests. For us at Very Good Ventures, the only solid set of tests are those that result in 100% code coverage. Setting this rule at the beginning of the project leads to an easier adoption and faster development.
:::

## Continuous Delivery (CD)

Continuous delivery is a practice that works alongside CI to automate the infrastructure provisioning phase and deployment process.

CD is responsible for creating the build that will be released and provisioning the resources that are required to deploy to a testing or production environment. CD requires software to be built in a way that allows it to be deployed at any point. In practice, this means that new functionality should be hidden behind a feature flag or use other techniques to prevent users from having a poor experience.

### Continuous Deployment

Continuous deployment is often confused with continuous delivery (CD), however, it is a subset of the delivery process. Continuous deployment allows teams to release their applications automatically when the criteria they've established for a release is met.

At Very Good Ventures, we often use a semi-automatic approach. We set up all the pipelines and the workflows to automatically deploy to the testing environment. However, we have a manual step to deploy to production.

## CI/CD pipeline

A CI/CD pipeline is a set of steps that run all the tasks we've discussed: testing, building, deploying, and any other steps that ensure the quality of our app and processes.

There are a variety of platforms where you can set up the CI/CD pipeline. At Very Good Ventures, we work by default with GitHub Actions due to its simplicity and ease of use with our repositories hosted in GitHub. For the mobile apps, we rely on [Codemagic][codemagic] for CD, thanks to its great integration with Flutter.

### GitHub Actions

[GitHub Actions][github_actions] is a CI/CD platform that allows you to automate builds, tests, and deployment. There are a variety of event triggers that you can use to run your pipeline, like opening a pull request, merging to main, pushing a commit, or manually triggering a workflow through the GitHub UI.

GitHub provides Linux, Windows and MacOS machines to run your workflows. You can also host your own runners in your data centers or cloud infrastructure.

#### Our recommendation

At Very Good Ventures, we have built a set of open source [Very Good Workflows][very_good_workflows] that help you run the most common tasks for Flutter and Dart applications.

For every project we work on, we set up a CI/CD pipeline that runs the following workflows for every pull request we open:

- [Flutter Package][flutter_package_workflow] for the main app and all flutter packages we build. This allows us to run all the automatic tests and ensure 100% code coverage.
- [Semantic Pull Request][semantic_pull_request_workflow]
- [Spell Check][spell_check_workflow]

:::tip
Check out some workflow examples we've used in projects like [I/O Crossword][crossword_workflows].
:::

### Codemagic

[Codemagic][codemagic] is a cloud-based CI/CD platform specifically designed for mobile developers. It is Very Good Ventures' preferred solution for releasing mobile apps, thanks to the ease of use when configuring code signing, certificates, and publishing to the stores.

### GitLab CI/CD

[GitLab CI/CD][gitlab_ci_cd] is the official CI/CD platform for GitLab. They offer a similar set of features as GitHub Actions, enabling us to apply the practices we've discussed above.

---

[ci_cd_gitlab]: https://about.gitlab.com/topics/ci-cd/
[github_actions]: https://docs.github.com/en/actions
[very_good_workflows]: https://workflows.vgv.dev/
[flutter_package_workflow]: https://workflows.vgv.dev/docs/workflows/flutter_package
[semantic_pull_request_workflow]: https://workflows.vgv.dev/docs/workflows/semantic_pull_request
[spell_check_workflow]: https://workflows.vgv.dev/docs/workflows/spell_check
[crossword_workflows]: https://github.com/VGVentures/io_crossword/tree/main/.github/workflows
[codemagic]: https://docs.codemagic.io/getting-started/about-codemagic/
[gitlab_ci_cd]: https://docs.gitlab.com/ee/ci/


# Code Reviews


Code reviews are an integral part of any high-quality software development workflow. Whether you're a reviewer or an author, following good practices will improve the team's productivity and code quality while ensuring a smoother development flow.
More than just a checkpoint, code review is a valuable opportunity for knowledge sharing, mentoring, and continuous learning. It’s a space to discuss best practices, teach and learn from one another, and align as a team on coding standards and architectural decisions.
Writing clean and readable code, preparing code for review, conducting thorough and effective code reviews, and using tools to automate parts of the process, are key points to keep a healthy codebase.

## Consider the review when writing code

When writing code it is essential to consider the review process right from the start. Code that’s designed with the reviewer in mind results in more efficient and productive code reviews, ultimately speeding up the development lifecycle.

- Prioritize clean and readable code: Adopting consistent coding styles and best practices helps to ensure that everyone on the team can easily understand and maintain each other's code. It also streamlines onboarding for new team members and enhances collaboration across the board.
- Keep PRs small and focused: Small PRs reduce review complexity, allow for faster feedback, and prevent blockers from piling up in the review pipeline. (Check out more reasons for small PRs from [Google's Engineering practices](https://google.github.io/eng-practices/review/developer/small-cls.html).)
- Incorporate review time in planning: The time it takes for your code to be reviewed, feedback to be incorporated, and any revisions to be made can have a huge impact on a task's overall timeline. Accurately accounting for this in your task estimations ensures more realistic deadlines and helps prevent bottlenecks.

## Preparing Code for Review

As an author, preparing for code review doesn’t only mean writing clean and maintainable code, but also providing context for reviewers to quickly understand what your code is doing.
Writing clear and comprehensive commit messages, along with relevant documentation and comments, is especially valuable when working with complex logic. It provides reviewers with deeper insights and makes it easier for them to understand your thought process.
It can also be helpful to request high-level or detailed feedback about specific code or concepts.

## Conducting Effective Code Reviews

Effective code reviews require a balance between attention to detail and a focus on the bigger picture. Making sure that we allocate enough time to review a pull request is critical to avoid missing anything.

### Code review etiquette

Here are some key principles for effective and respectful code review communication:

#### Be Constructive and Actionable

Focus on feedback that helps the author improve by offering clear suggestions for how to address issues. Avoid vague comments and ensure that your feedback points toward a specific, actionable improvement.

#### Balance Criticism with Praise

Recognize what’s done well before highlighting areas that need improvement. Acknowledging strengths helps build confidence while making the author more receptive to constructive criticism.

#### Focus on Clarity, Maintainability, and Correctness

Ensure that the code adheres to team standards and is easy to read and maintain. It’s not just about fixing errors but also about making the code cleaner and more understandable for future developers.

#### Recognize Effort and Intent

Appreciate the time and thought put into the code, even when revisions are needed. A small note of recognition goes a long way in maintaining a collaborative and supportive team atmosphere.

#### Encourage Collaboration

Frame feedback in a way that invites open discussion and solutions. This creates a culture of shared decision-making and helps the author feel like part of the process rather than simply receiving orders.

By adhering to these practices, you can create a code review culture that improves the code while fostering collaboration, mutual respect, and growth within the team.

## Collaboration and Communication

Good collaboration in code reviews starts before the code is written by anticipating complex changes or implementations and engaging the team in discussions early in the process. By aligning on the approach upfront, reviews become smoother and more efficient.

The actual code review also goes beyond pointing out errors; it requires open communication and empathy. When providing feedback, focus on constructive and actionable comments that help the author understand the problem and how to address it.

## Tools and Automation in Code Reviews

Automation plays a key role in making code reviews more efficient and consistent. By integrating linters and static analysis tools, teams can enforce coding standards and catch errors automatically, allowing reviewers to focus more on logic and architecture.

At Very Good Ventures, we use our open source analysis tool [`very_good_analysis`](https://github.com/VeryGoodOpenSource/very_good_analysis). We believe these linting rules create a healthier, more scalable codebase.

Nowadays there are also many AI tools that can assist in code reviews, providing suggestions and identifying potential issues. While these tools can be helpful, they should not replace human reviewers and as they're non-deterministic, should be paired with lint rules and testing.
Also, any code generated by AI should be carefully reviewed.

## Post-Review: Merging and Follow-Up

Once the code review is complete, it’s important to make sure that all feedback has been properly addressed before merging. When merging, consider best practices like squashing commits to keep your repository's git history clean and concise.

## Conclusion

Effective code reviews are essential for maintaining a high-quality, maintainable codebase while fostering a collaborative and efficient development process. By prioritizing clear communication, leveraging tools to automate mundane checks, and focusing on collaboration, teams can ensure a smoother, more effective development workflow.


# Code Style


import { TabItem, Tabs } from "@astrojs/starlight/components";

In general, the best guides for code style are the [Effective Dart](https://dart.dev/effective-dart) guidelines and the linter rules set up in [very_good_analysis](https://pub.dev/packages/very_good_analysis). However, there are certain practices we've learned outside of these two places that will make code more maintainable.

## Record Types

Among other things, the release of Dart 3.0 introduced [record types](https://dart.dev/language/records), a way to store two different but related pieces of data without creating a separate data class. When using record types, be sure to choose expressive names for positional values.

<Tabs>
  <TabItem label="Bad ❗️">
    ```dart
    Future<(String, String)> getUserNameAndEmail() async => _someApiFetchMethod();

    final userData = await getUserNameAndEmail();

    // a bunch of other code...

    if (userData.$1.isValid) {
      // do stuff
    }
    ```

  </TabItem>
</Tabs>

The above example will compile, but it is not immediately obvious what value `userData.$1` refers to here. The name of the function gives the reader the impression that the second value in the record is the email, but it is not clear. Particularly in a large codebase, where there could be more processing in between the call to `getUserNameAndEmail()` and the check on `userData.$1`, reviewers will not be able to tell immediately what is going on here.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    Future<(String, String)> getUserNameAndEmail() async => _someApiFetchMethod();

    final (username, email) = await getUserNameAndEmail();

    // a bunch of other code...

    if (email.isValid) {
      // do stuff
    }
    ```

  </TabItem>
</Tabs>

Now, we are expressly naming the values that we are getting from our record type. Any reviewer or future maintainer of this code will know what value is being validated.

:::tip
While this is our recommended practice for dealing with record types, you might want to consider whether you actually need a record type. Particularly in larger projects where you are using values across multiple files, dedicated data models may be easier to read and maintain.
:::

## Prefer Widgets to Methods

We prefer creating widgets over creating methods that return `Widget`.

<Tabs>
    <TabItem label="Bad ❗️">
      ```dart
      class ParentWidget extends StatelessWidget {
        const ParentWidget({super.key});

        \@override
        Widget build(BuildContext context) {
          return _buildChildWidget(context);
        }

        Widget _buildChildWidget(BuildContext context) {
          return const Text('Hello World!');
        }
      }
      ```
    </TabItem>
    <TabItem label="Good ✅">
      ```dart
      class ParentWidget extends StatelessWidget {
        const ParentWidget({super.key});

        \@override
        Widget build(BuildContext context) {
          return ChildWidget();
        }
      }

      class ChildWidget extends StatelessWidget {
        const ChildWidget({super.key});

        \@override
        Widget build(BuildContext context) {
          return const Text('Hello World!');
        }
      }
      ```
    </TabItem>

</Tabs>

We prefer this for a few reasons:

1. It avoids coding errors caused by passing around the wrong `BuildContext`. Flutter manages the `BuildContext` via the widget tree, which is more reliable.

2. The widgets are added to the widget tree, which allows for more potentially efficient rendering and enables inspecting them in the debug tools.

3. Widgets are easier to test as they can be tested in isolation. They don't required building the `ParentWidget` to test the `ChildWidget`.

For more details, check out the following video:

<iframe
  style="width: 100%; height: 480px;"
  src="https://www.youtube.com/embed/IOyq-eTRhvo?si=pr_2yp_tr94EJztF"
  title="YouTube video player"
  frameborder="0"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
  referrerpolicy="strict-origin-when-cross-origin"
  allowfullscreen
></iframe>


# Documentation


import { TabItem, Tabs } from "@astrojs/starlight/components";

As Flutter projects grow, maintaining consistency across teams and repositories becomes increasingly difficult, but also increasingly essential.
In this article, we’ll walk through a set of actionable practices that help teams build scalable, maintainable apps by
investing in strong documentation and clear development standards.

## Documentation That Lives With the Code

Good documentation doesn't live in a vacuum. It lives alongside your code, evolves with it, and makes your project more accessible to newcomers and seasoned developers alike.
Here’s what that looks like in practice:

### At the App Level

- **README as the Single Source of Truth**
  Every repository should have a README that answers key questions:

      - What are the requirements to run the project?

      - How do I run this project? (Ideally in one command.)

      - Where can I learn about architecture?

      - What state management strategy is used, and why?

      - Are there any debugging tips (e.g., Sentry, session replay)?

      - Localization and internationalization setup

- **Docs Folder for Extended Guides**
  Use a /docs folder to centralize everything that doesn’t belong in the README but is still critical:

      - State management conventions

      - Dependency injection setup

      - Feature/module boundaries

      - ADRs (Architecture Decision Records)

      - Accessibility guide

**_Note_**: Keeping these documents up to date is crucial. If they become stale, they lose their value. Regularly review and update them as part of your development cycle.

- **Architecture Decision Records**
  ADRs help capture why certain decisions were made. Hosting them in version control keeps the context accessible to the whole team, not just the people who were around at the time.

### At the Package Level

- **Self-Contained README**
  Each package should include its own README that:

      - Describes the package’s purpose and what problem it solves

      - Explains how to use the package

      - Lists its own dependencies, peer packages, or environment requirements

- **Self explained and Balance Repetition**
  Avoid assuming readers will reference the root-level README. Package-level documentation should be understandable in isolation, especially when packages are reused or shared across projects.

## Document External Tools

Many Flutter apps rely on external tools for internationalization, code generation, or DevOps workflows. When these tools are part of the development workflow, they should be explicitly documented to reduce onboarding friction and prevent misuse.

- **Add Dedicated Sections for Critical Tools**
  If your project depends on tools like build_runner, custom_lint, or flutter gen-l10n, document their purpose and usage directly in the README or linked documentation.

- **Include actionable Commands**
  Copy-pasteable CLI commands, expected file locations, and regeneration steps are essential. Avoid vague notes like "run codegen", be precise.

- **Clarify When & Why to Use the Tool**
  Include context on why the tool is present and when it should or shouldn’t be used: - Where the config lives (e.g., l10n.yaml, .dart_tool/, pubspec.yaml)

      - How and When the tool should be run

      - Any common pitfalls or edge cases developers should watch for

- **Define Standards, Not Just Steps**
  If a tool supports flexibility, define the conventions your team adopts, this avoids ambiguity and prevents fragmentation over time.

## Coding Standards Aren’t Optional

Without clearly defined development practices, teams tend to reinvent the wheel,or worse, misalign entirely. Defining coding standards early sets the bar for maintainability, scalability, and code review quality.
Here’s what to focus on:

- **State Management Patterns**
  Document not just what is used (e.g., Riverpod), but how. Define preferred patterns, common pitfalls, and where shared logic should live.

- **Dependency Injection**
  Don’t just rely on DI tools—explain the philosophy behind their usage. Clarify lifecycle expectations, testability benefits, and error boundaries.

- **Folder Structures**
  If you adopt a modular or feature-driven architecture, enforce it. Consistency helps reduce cognitive load and onboarding time.

- **Naming Conventions & Lint Rules**
  Use a consistent naming scheme, and automate enforcement with tools like very_good_analysis. Fewer surprises = faster development.

## Documenting Design Systems & Widgets

Reusable UI components are only as effective as their documentation. While some tools provide visual context, they’re not a substitute for structured documentation.
To improve discoverability and reduce developer friction:

- **Document All Public Widgets and APIs**
  Use the public_member_api_docs rule, from the [https://pub.dev/packages/very_good_analysis](very_good_analysis package), to enforce this automatically. If it’s public, it should be documented.

- **Adopt a Consistent Format**
  Each widget should include:

      - A clear description of its purpose

      - Required vs. optional parameters

      - Expected usage or constraints

- **Go Beyond Visuals**
  Visual reference is helpful, but developers still need to understand when and why to use a widget. Written docs fill that gap.

## Consider using asserts over inline comments

[Dart asserts](https://dart.dev/language/error-handling#assert) with messages enforce conditions during development and
provide immediate feedback if something goes wrong, while an inline comment only document the code and don't immediately prevent errors.
Assertions help catch issues early, making debugging easier and more reliable.

<Tabs>
  <TabItem label="Good ✅">

```dart
(double?, double?) solveQuadraticEquation(double a, double b, double c) {
  assert(
    a != 0,
    'The coefficient of the square term must not be zero, otherwise is not a '
    'quadratic equation.',
  );

  final discriminant = b * b - 4 * a * c;
  return switch (discriminant) {
    final d when d > 0 => ((-b + sqrt(d)) / (2 * a), (-b - sqrt(d)) / (2 * a)),
    final d when d == 0 => (-b / (2 * a), null),
    _ => (null, null),
  };
}
```

  </TabItem>
  <TabItem label="Bad ❗️">

```dart
(double?, double?) solveQuadraticEquation(double a, double b, double c) {
  // The coefficient of the square term must not be zero otherwise is not a
  // quadratic equation.

  final discriminant = b * b - 4 * a * c;
  return switch (discriminant) {
    final d when d > 0 => ((-b + sqrt(d)) / (2 * a), (-b - sqrt(d)) / (2 * a)),
    final d when d == 0 => (-b / (2 * a), null),
    _ => (null, null),
  };
}
```

  </TabItem>
</Tabs>

## Why This Matters

These practices aren't just about process, they're about building trust in your codebase.
When documentation is complete and development standards are shared, teams move faster, onboard easier, and deliver with more confidence.
And like most things in engineering, the earlier you invest in these foundations, the more they’ll pay off as your project scales.


# Code Documentation


import { TabItem, Tabs } from "@astrojs/starlight/components";

## Explicitly document no operations

On occasions, some code might simply do nothing at all, these scenarios are usually referred to as [no operations (no-op)](<https://en.wikipedia.org/wiki/NOP_(code)>).
The reasons for the need to introduce a no-op may vary. For example, it could well be due to the need to align with an interface.

Leaving the no-operation without an explanatory comment may cause engineers to doubt whether
the code was left uncompleted intentionally or not. If there is a need for a no-op, document its existence.

The same principle would apply if a comment left is not clear enough.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
class BluetoothProcessor extends NetworkProcessor {
      \@override
      void abort() {
          // Intentional no-op, an abort in Bluetooth has no resources to clean.
      }
}
```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
class BluetoothProcessor extends NetworkProcessor {
      \@override
      void abort() {}
}
    ```
  </TabItem>
</Tabs>


# Error handling


import { FileTree, TabItem, Tabs } from "@astrojs/starlight/components";

## Document when a call may throw

Document exceptions associated with calling a function in its documentation comments to help understand when an exception might be thrown.

Properly documenting possible exceptions allows developers to handle exceptions, leading to more robust and error-resistant code and reducing the likelihood of unintended errors.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    /// Permanently deletes an account with the given [name].
    ///
    /// Throws:
    ///
    /// * [UnauthorizedException] if the active role is not [Role.admin], since only
    ///  admins are authorized to delete accounts.
    void deleteAccount(String name) {
      if (activeRole != Role.admin) {
        throw UnauthorizedException('Only admin can delete account');
      }
      // ...
    }
    ```
  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    /// Permanently deletes an account with the given [name].
    void deleteAccount(String name) {
      if (activeRole != Role.admin) {
        throw UnauthorizedException('Only admin can delete account');
      }
      // ...
    }
    ```
  </TabItem>
</Tabs>

## Define descriptive exceptions

Implement `Exception` with descriptive names rather than simply throwing a generic `Exception`.

By creating custom exceptions, developers can provide more meaningful error messages and handle different error types in a more granular way. This enhances code readability and maintainability, as it becomes clear what type of error is being dealt with.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    class UnauthorizedException implements Exception {
      UnauthorizedException(this.message);

      final String message;

      \@override
      String toString() => 'UnauthorizedException: $message';
    }

    void deleteAccount(String name) {
      if (activeRole != Role.admin) {
        throw UnauthorizedException('Only admin can delete account');
      }
      // ...
    }

    void main() {
      try {
        deleteAccount('user');
      } on UnauthorizedException catch (e) {
        // Handle the exception.
      }
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    void deleteAccount(String name) {
      if (activeRole != Role.admin) {
        throw Exception('Only admin can delete account');
      }
      // ...
    }

    void main() {
      try {
        deleteAccount('user');
      } on Exception catch (e) {
        // Exception is a marker interface implemented by all core library exceptions.
        // It is very generic, potentially catching many different types of exceptions,
        // lacking intent, and making the code harder to understand.
      }
    }
    ```

  </TabItem>
</Tabs>


# Localization


In the modern and global world, it is likely that your app will be used by people that speak another language. With internationalization, you will write your app in a way that allows you to easily change texts and layouts based on the user language.

Even if you are not planning to support other languages in your app's first version, **we highly recommend using internationalization**. The overhead is small and the advantages in the long run are big, making your project scalable and setting it up for success.

## Definitions

Before we start with the recommendations, let's define some terminology:

- Locale: Set of properties that define the user region, language and other user preferences like the currency, time or number formats.[^1]
- Localization: Process of adapting software for a specific language by translating text and adding region specific layouts and components.[^1]
- Internationalization: Process of designing software in a way that can be adapted (localized) to different languages without engineering changes.[^1]

[^1]: Richard Ishida, W3C, Susan K. Miller, Boeing. [Localization vs Internationalization][i18n_l10n_locale_definitions]

:::note
Internationalization is often referred as i18n and localization as l10n since the 18 and 10 in both acronyms refer to the number of characters between the first and the last letters of each term.
:::

## Frontend

We can use Flutter's built-in support for localization.

1. Start by setting up internationalization. In Flutter, you will have to install the `flutter_localizations` and `intl` packages. Also, enable the `generate` flag in the `flutter` section of the pubspec file:

```yaml
flutter:
  generate: true
```

2. Add a localization configuration file in the root directory of your project, called `l10n.yaml` with the following content:

```yaml
arb-dir: lib/l10n/arb
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
preferred-supported-locales: [en]
```

Make sure to update these values based on your needs. We recommend setting up the preferred locale manually to avoid Flutter selecting it from a list in alphabetical order.

:::note
Check out the [documentation][l10n_file_documentation] regarding the configuration values supported by the `l10n.yaml` file to know more.
:::

3. Create your template localization file inside `<PROJECT>/lib/l10n/arb/` called `app_en.arb`.

```json
{
  "helloWorld": "Hello World!"
}
```

4. Add other languages by creating new App Resource Bundle (.arb) files in the same folder. For example let's create the Spanish translation in `app_es.arb`.

```json
{
  "helloWorld": "¡Hola Mundo!"
}
```

5. Generate the localization files to be used across the app by running `flutter gen-l10n`.

6. Add the localizations delegates and supported locales to your app widget:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

const MaterialApp(
  title: 'Localizations Sample App',
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);
```

7. Finally, you can use your localized messages across the app.

```dart
Text(
  AppLocalizations.of(context).helloWorld,
  style: Theme.of(context).textTheme.bodyMedium,
)
```

:::tip
If you find yourself repeating `AppLocalizations.of(context)` many times and find it cumbersome, you can create an extension to make it easier to access the localized strings:

```dart
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

:::

Check out the [Flutter documentation][flutter_i18n_docs] on this topic to find more details about the implementation.

:::tip
You can save time configuring the localizations when creating a new project by using Very Good CLI and running `very_good create flutter_app <app_name>`. This command will create the demo counter app with the English template file and all the internationalization configuration to start using it, as well as a readme section explaining how to add new strings.
:::

### UI Libraries

It's common to create components in a different package that do not have access to the localized strings. The easiest solution to support localization is to allow these components to receive the required strings as parameters, passing them from the main app.

## Backend

Some applications don't require the backend to send any user-facing strings to the frontend. However, there are cases where this is needed, like a recipes app where you won't be storing all recipes in the device. To internationalize your app, you can follow a similar approach as we did for the frontend:

- Create database entries with translated content for each language you want to support.
- Require client to transmit the user's locale with a backend request or when starting a session.
- Decide which string should be returned based on the user locale.

### Error messages

We can leverage multiple error-handling strategies on the client-side: silently fail, retry, show a message, etc. Whenever an error message is received, however, it must be localized.

We recommend that the backend return the appropriate [HTTP status codes][http_status_codes] so the frontend can map those codes to localization keys and custom messages.

However, there are times where the HTTP status code does not give enough information and we want to be more specific to the user. In these cases, we should return an error constant and map it to a localized string in the app. For example, if we have a shopping cart where we can use a promo code, the server could return a 400 (bad request) with a custom error code in the body if the promo code was invalid: `invalid_code`, `expired_code`, `limit_reached`, `unqualified_item`, `already_used`, etc.

---

[i18n_l10n_locale_definitions]: https://www.w3.org/International/questions/qa-i18n
[l10n_file_documentation]: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization#configuring-the-l10n-yaml-file
[flutter_i18n_docs]: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
[http_status_codes]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status


# Text Directionality


import { Image } from "astro:assets";
import bikeBidirectional from "./images/bike_bidirectional.png";
import directionExample from "./images/text_direction_figure_1.png";

Supporting variable text directions is a critical component of internationalization. While many languages such as English are read left-to-right (LTR), a great number including Arabic, Hebrew, and Farsi are read right-to-left (RTL). Text directionality impacts not only how text itself is displayed, but the layout and design of your app as a whole.

Fortunately, Flutter provides robust capabilities for handling variable text directions. Utilizing these correctly will allow your application to make visual sense to all users.

Let's explore how Flutter handles text directionality and discuss important guidelines for ensuring your app supports both LTR and RTL text flawlessly.

### How Flutter Handles Text Directionality

The [`Directionality`](https://api.flutter.dev/flutter/widgets/Directionality-class.html) widget is the basis of direction handling in Flutter. Its `textDirection` property controls how direction is assigned and can have a value of `TextDirection.ltr` or `TextDirection.rtl`, which will be furnished as a default text direction to all of the widget's children.

A default global `Directionality` exists across the widget layer in Flutter and is determined by the user's locale. See the [Internationalizing Flutter Apps](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization) documentation for more information on locales in Flutter.

:::note
`Directionality.of(context)` will return the directionality of a given `BuildContext`.
:::

Directionality can also be explicitly supplied to widgets through use of the `Directionality` widget as a parent.

Let's observe how directionality impacts the display of various elements in a flutter app. Here we have a `Directionality` widget which furnishes a variable text direction to a row and its children:

```dart
Directionality(
  textDirection: textDirectionLTR ? TextDirection.ltr : TextDirection.rtl,
  child: Row(
    children: [
        // children
    ],
  ),
),
```

<Image
  src={directionExample}
  alt="Table comparing directional variants of one text widget, two text widgets, and two container widgets."
/>

As you can see in the first 'hello world' example, the text becomes right-aligned once `textDirection` is RTL, but the string remains displayed as typed. RTL strings are entered right-to-left and thus are handled the same way.

Note that in the second, 'hello', 'world', example that the order of _elements_ will be flipped for ordered, direction-sensitive widgets such as this `Row`. This applies to non-text elements as well, as illustrated by the third example displaying colored boxes in a row.

:::note
Flutter uses the [Unicode Bidirectional Algorithm](https://unicode.org/reports/tr9/) to determine the visual representation order of text. Read more about the algorithm to understand how text elements like mixed-directionality strings, unicode control characters, and punctuation are displayed.
:::

### Tips for Handling Directionality in Flutter Like a Pro

#### **Know when to use _visual_ versus _directional_ widgets.**

The mirroring behavior exhibited by text-direction-sensitive widgets presents a unique challenge for developers. For example, how are text-aligned elements supposed to maintain their relative position when the alignment of the text itself is being flipped? What about widgets that require an _absolute_ position independent of any text direction changes?

Flutter has introduced a powerful system for expressing the precise behavior you want for many direction-sensitive widgets, but it's important to understand its details in order to get the most out of your bidirectional app.

Flutter offers both visually- and directionally-demarcated versions of many relevant widgets and values. Visually-based values are defined in absolute directions such as `top`, `left`, `right`, and `bottom`. Directionally-based widgets, by contrast, are defined in terms relative to the widget's directional alignment: `top`, `start`, `end`, and `bottom`.

This distinction is illustrated by comparing the `EdgeInsets` and `EdgeInsetsDirectional` classes. If we want to introduce a padding value that always comes before the beginning of a text widget, `EdgeInsetsDirectional` allows us to maintain that relative position regardless of the text's orientation:

```dart
Padding(
    padding: EdgeInsetsDirectional.only(start: 12),
    child: Text('Whether RTL or LTR, padding will always be at the start of this string!'),
),
Padding(
    padding: EdgeInsets.only(left:  10),
    child: Text('Padding will always be to the left of this string!'),
)
```

Many Flutter widgets, including `Positioned` and `Border`, have `Directional` variants that will allow you to specify the exact relationship you want them to have with directionality.

#### **Account for non-text elements.**

Text isn't the only content in your app that changes with directionality! Many Flutter icons will also by default be mirrored when the text direction flips:

<Image
  src={bikeBidirectional}
  alt="Left-to-right and right-to-left variants of a bicycle icon."
/>
_Icons.directions_bike in LTR and RTL alignments (source: [material.io)](https://m2.material.io/design/usability/bidirectionality.html#mirroring-elements)_

:::note
If you want an icon to retain a static direction, set it in the `Icon`'s `textDirection` field.
:::

Images may need to be flipped as well. `Image` and most other default graphics widgets have a `matchTextDirection` property which is `false` by default. When set to `true`, the image will be drawn starting from the top left (default behavior) in LTR environments, and from the top right in RTL environments, mirroring the image.

#### **Follow bidirectional mirroring standards.**

There are established guidelines for which elements should and should not be mirrored when switching between LTR and RTL layouts. For example, visual references to a forward direction or future time (e.g. an arrow pointing right in an LTR layout) should be mirrored, whereas media progress indicators should remain oriented LTR as they model the direction of a tape being played.

There are similar conventions in place for negation symbols, physical objects, and other potentially bidirectional components. Adhering to these standards is essential for a clear and globally comprehensible user interface. For an overview of bidirectional design conventions, read Material Design's [Bidirectionality](https://m2.material.io/design/usability/bidirectionality.html) guide.


# Routing Overview


import { TabItem, Tabs } from "@astrojs/starlight/components";

Navigation is a crucial component of any app. A declarative routing structure is essential for building scalable apps that function seamlessly on both mobile and web platforms. At VGV, we recommend using the [GoRouter](https://pub.dev/packages/go_router) package for handling navigation needs, as it provides a robust and flexible solution for managing routes.

### GoRouter

[GoRouter](https://pub.dev/packages/go_router) is a popular routing package that is maintained by the Flutter team. It is built on top of the [Navigator 2.0](https://docs.flutter.dev/ui/navigation#using-router-and-navigator-together) API and reduces much of the boilerplate code that is required for even simple navigation. It is a declarative routing package with a URL-based API that supports parsing path and query parameters, redirection, sub-routes, and multiple navigators. Additionally, GoRouter works well for both mobile and web apps.

### Configuration

To enable deep linking in your app (such as redirecting to a login page or other features), routing must be carefully configured to properly support backwards navigation.

Structure your routes in a way that makes logical sense. Avoid placing all of your routes on the root path. Instead, use sub-routes.

<Tabs>
  <TabItem label="Good ✅">
    ```txt
    /
    /flutter
    /flutter/news
    /flutter/chat
    /android
    /android/news
    /android/chat
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```txt
    /
    /flutter
    /flutter-news
    /flutter-chat
    /android
    /android-news
    /android-chat
    ```

  </TabItem>
</Tabs>

:::note
Not only does using sub-routes make the path more readable, it also ensures that the app can navigate backwards correctly from the child pages.
:::

### Use type-safe routes

GoRouter allows you to define [type-safe routes](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html). When routes are type-safe, you no longer have to worry about typos and casting your route's path and query parameters to the correct type.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    \@TypedGoRoute<CategoriesPageRoute>(
      name: 'categories',
      path: '/categories',
    )
    \@immutable
    class CategoriesPageRoute extends GoRouteData {
      const CategoriesPageRoute({
        this.size,
        this.color,
      });

      final String? size;
      final String? color;

      \@override
      Widget build(context, state) {
        return CategoriesPage(
          size: size,
          color: color,
        );
      }
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    GoRoute(
      name: 'categories',
      path: '/categories',
      builder: (context, state) {
        final size = state.uri.queryParameters['size'];
        final color = state.uri.queryParameters['category'];
        return CategoriesPage(size: size, color: color);
      }
    )
    ```

  </TabItem>
</Tabs>

Navigating to the `categories` page using the type-safe route is as simple as calling:

```dart
const CategoriesPageRoute(size: 'small', color: 'blue').go(context);
```

:::note
When needing to route to a page from a deep link, it is still possible to use the route's name/path and query parameters. However, using type-safe routes is recommended for navigating within the app. If your deep links are coming from an external source, choose the method that best fits your needs.

For reasons listed in the [Prefer navigating by name over path](#prefer-navigating-by-name-over-path) section below, navigating by name is preferred over navigating by path.

<Tabs>
  <TabItem label="Navigating by name">
    ```dart
    context.goNamed('categories', queryParameters: {'size': 'small', 'color': 'blue'})
    ```

  </TabItem>
  <TabItem label="Navigating by path">
    ```dart
    context.go('/categories?size=small&color=blue');
    ```

  </TabItem>
</Tabs>

:::

### Prefer `go` over `push` methods

GoRouter offers multiple ways to navigate to a route, such as pushing every route onto the stack and navigating to a route's path.

When possible, use GoRouter's `go` methods for navigation. Calling `go` pushes a new route onto the navigation stack according to your route's path and updates the path in your browser's URL address bar (if on web).

Use the `push` method for navigation when you are expecting to receive data from a route when it is popped. Popping with data is a common scenario when pushing a dialog onto the stack which collects input from the user. Since you will never be expected to route the user directly to the dialog from a deep link, using `push` prevents the address bar from updating the route.

:::note
It is possible, however, to update the path in the URL address bar when using `push` by adding the following:

```dart
GoRouter.optionURLReflectsImperativeAPIs = true;
```

Note that we do not recommend modifying the behavior of `push` in this way unless you are in the process of [migrating](https://docs.google.com/document/d/1VCuB85D5kYxPR3qYOjVmw8boAGKb7k62heFyfFHTOvw/edit) to GoRouter 8.0.0.

For more information on the differences between `go` and `push`, read this [Code with Andrea article](https://codewithandrea.com/articles/flutter-navigation-gorouter-go-vs-push/).
:::

Using `go` will ensure that the back button in your app's `AppBar` will display when the current route has a parent that it can navigate backwards to. Root paths will not display a back button in their `AppBar`. For example, `/flutter/news` would display a back arrow in the `AppBar` to navigate back to `/flutter`, but `/flutter` would not not display a back button. Using sub-routes correctly removes the need to manually handle the back button functionality.

:::note
In a Flutter web app, the browser's back button will still be enabled as long as there are pages on the navigation stack, regardless of the navigation method that is used. Using redirects correctly will help ensure that the back button functions according to your app's navigation structure.
:::

#### Use hyphens for separating words in a URL

Mobile app users will likely never see your route's path, but web app users can easily view it in the browser's URL address bar. Your routing structure should be consistent and defined with the web in mind. Not only does this make your paths easier to read, it allows you the option of deploying your mobile app to the web without any routing changes needed.

<Tabs>
  <TabItem label="Good ✅">
    ```txt
    /user/update-address
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```txt
    /user/update_address
    /user/updateAddress
    ```

  </TabItem>
</Tabs>

:::note
For a full list of URL structure best practices, take a look at this [document](https://developers.google.com/search/docs/crawling-indexing/url-structure) from Google.
:::

#### Prefer navigating by name over path

If you're using GoRoute's type-safe routes, navigate using the `go` extension method that was generated for your route.

```dart
FlutterNewsPageRoute().go(context);
```

If a route to a page is given to you from an external source, such as a push notification, to deep link to a specific page within your app, GoRouter allows you to navigate to a route by its name or by its path.

Because your app's structure and paths can change over time, we recommend routing by name to avoid potential issues of a route's path getting out of sync.

Consider this situation: An app has a route defined with the path `/flutter-news` for the `FlutterNewsPage`.

```dart
\@TypedGoRoute<FlutterNewsPageRoute>(
  name: 'flutterNews',
  path: '/flutter-news',
)
\@immutable
class FlutterNewsPageRoute extends GoRouteData {
  \@override
  Widget build(context, state) {
    return const FlutterNewsPage();
  }
}
```

Later, the pages in the app were reorganized and the path to the `FlutterNewsPage` has changed.

```dart
\@TypedGoRoute<TechnologyPageRoute>(
  name: 'technology',
  path: '/technology',
  routes: [
    TypedGoRoute<FlutterPageRoute>(
      name: 'flutter',
      path: 'flutter',
      routes: [
        TypedGoRoute<FlutterNewsPageRoute>(
          name: 'flutterNews',
          path: 'news',
        ),
      ],
    ),
  ],
)
```

If the app was relying on the `path` to navigate the user to the `FlutterNewsPage` and the deep link path from the external source didn't match the route's path, the route would not be found. However, when relying on the route `name`, navigation would work in either situation.

#### Extension methods

GoRouter provides extension methods on `BuildContext` to simplify navigation. For consistency, use the extension method over the longer `GoRouter` methods since they are functionally equivalent.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    context.goNamed('flutterNews');
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    GoRouter.of(context).goNamed('flutterNews');
    ```

  </TabItem>
</Tabs>

### Navigating with parameters

Many times when navigating, you need to pass data from one page to another. GoRouter makes this easy by providing multiple ways to accomplish this: path parameters, query parameters, and an extra parameter.

#### Path parameters

Use path parameters when identifying a specific resource.

```txt
/article/whats-new-in-flutter
```

To navigate to the details page of a particular article, the `GoRoute` would look like this:

```dart
// ...
\@TypedGoRoute<FlutterArticlePageRoute>(
  name: 'flutterArticle',
  path: 'article/:id',
)
\@immutable
class FlutterArticlePageRoute extends GoRouteData {
  const FlutterArticlePageRoute({
    required this.id,
  });

  final String id;

  \@override
  Widget build(context, state) {
    return FlutterArticlePage(id: id);
  }
}
// ...
```

Navigating to that page with the article id is as simple as providing the article id to the `FlutterArticlePageRoute`'s constructor:

```dart
FlutterArticlePageRoute(id: article.id).go(context);
```

#### Query parameters

Use query parameters when filtering or sorting resources.

```txt
/flutter/articles?date=07162024&category=all
```

To navigate to a page of filtered articles, the `GoRoute` would look like this:

```dart
// ...
\@TypedGoRoute<FlutterArticlesPageRoute>(
  name: 'flutterArticles',
  path: 'articles',
)
\@immutable
class FlutterArticlesPageRoute extends GoRouteData {
  const FlutterArticlesPageRoute({
    this.date,
    this.category,
  });

  final String? date;
  final String? category;

  \@override
  Widget build(context, state) {
    return FlutterArticlesPage(
      date: date,
      category: category,
    );
  }
}
// ...
```

:::note
Unlike path parameters, query parameters do not have to be defined in your route path.
:::

To navigate to the list of filtered articles:

```dart
FlutterArticlesPageRoute(date: state.date, category: state.category).go(context);
```

#### Extra parameter

GoRouter has the ability to pass objects from one page to another. Most of the time, however, we avoid using the `extra` object when navigating to a new route.

:::caution
The `extra` option used during navigation does not work on the web and cannot be used for deep linking, so we do not recommend using it.
:::

<Tabs>
  <TabItem label="Bad ❗️">
    ```dart
    \@TypedGoRoute<FlutterArticlePageRoute>(
      name: 'flutterArticle',
      path: 'article',
    )
    \@immutable
    class FlutterArticlePageRoute extends GoRouteData {
      const FlutterArticlePageRoute({
        required this.article,
      });

      final Article article;

      \@override
      Widget build(context, state) {
        return FlutterArticlePage(article: article);
      }
    }
    ```

    ```dart
    FlutterArticlePageRoute(article: article).go(context);
    ```

  </TabItem>
</Tabs>

In this example, we are passing the `article` object to the article details page. If your app is designed to only work on mobile and there are no plans of deep linking to the articles details page, then this is fine. But, if the requirements change and now you want to support the web or deep link users directly to the details of a particular article, changes will need to be made. Instead, pass the identifier of the article as a path parameter and fetch the article information from inside of your article details page.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    FlutterArticlePageRoute(id: state.article.id).go(context);
    ```

    ```dart
    \@TypedGoRoute<FlutterArticlePageRoute>(
      name: 'flutterArticle',
      path: 'article/:id',
    )
    \@immutable
    class FlutterArticlePageRoute extends GoRouteData {
      const CategoriesPageRoute({
        required this.id,
      });

      final String id;

      \@override
      Widget build(context, state) {
        return FlutterArticlePage(id: id);
      }
    }
    ```

  </TabItem>
</Tabs>

:::note
This does not necessarily mean that you have to make another network request to fetch the article information if you already have it. You may need to refactor your repository layer to retrieve the article information from the cache if the data has already been fetched, otherwise make the request to fetch the article information.
:::

### Redirects

Sometimes you need to redirect users to a different location in the app. For example: only signed-in users can access parts of your app. If the user isn't signed-in, you want to redirect the user to the sign in page. Fortunately, GoRouter makes this very easy and redirects can be done at the root and sub-route level.

```dart
class AppRouter {
  AppRouter({
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    _goRouter = _routes(
      navigatorKey,
    );
  }

  late final GoRouter _goRouter;

  GoRouter get routes => _goRouter;

  GoRouter _routes(
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    return GoRouter(
      initialLocation: '/',
      navigatorKey: navigatorKey,
      redirect: (context, state) {
        final status == context.read<AppBloc>().state.status;

        if (status == AppStatus.unauthenticated) {
          return SignInPageRoute().location;
        }

        return null;
      },
      routes: $appRoutes,
    )
  }
}
```

```dart
\@TypedGoRoute<HomePageRoute>(
  name: 'home',
  path: '/',
)
\@immutable
class HomePageRoute extends GoRouteData {
  const HomePageRoute();

  \@override
  Widget build(context, state) {
    return HomePage();
  }
}

\@TypedGoRoute<SignInPageRoute>(
  name: 'signIn',
  path: '/sign-in',
)
\@immutable
class SignInPageRoute extends GoRouteData {
  const SignInPageRoute();

  \@override
  Widget build(context, state) {
    return SignInPage();
  }
}
```

:::note
Redirects on the parent routes are executed first. This is another reason why it is important to organize your URL hierarchy in a way where one redirect on a parent route can apply to all of the sub-routes.
:::

In this example, the user is redirected to the `restricted` page if the user's status isn't `premium` and tries to access `/premium`, `/premium/show`, or `/premium/merch`. Having `shows` and `merch` as sub-routes avoids having to add redirect logic to each route.

```dart
\@TypedGoRoute<PremiumPageRoute>(
  name: 'premium',
  path: '/premium',
  routes: [
    TypedGoRoute<PremiumShowsPageRoute>(
      name: 'premiumShows',
      path: 'shows',
    ),
    TypedGoRoute<PremiumMerchPageRoute>(
      name: 'premiumMerch',
      path: 'merch',
    ),
  ],
)
\@immutable
class PremiumPageRoute extends GoRouteData {
  const PremiumPageRoute();

  \@override
  Widget build(context, state) {
    return PremiumPage();
  }

  \@override
  String? redirect(context, state) {
    final status == context.read<AppBloc>().state.user.status;

    if (status != UserStatus.premium) {
      return RestrictedPageRoute().location;
    }

    return null;
  }
}

\@immutable
class PremiumShowsPageRoute extends GoRouteData {
  const PremiumShowsPageRoute();

  \@override
  Widget build(context, state) {
    return PremiumShowsPage();
  }
}

\@immutable
class PremiumMerchPageRoute extends GoRouteData {
  const PremiumMerchPageRoute();

  \@override
  Widget build(context, state) {
    return PremiumMerchPage();
  }
}

\@TypedGoRoute<RestrictedPageRoute>(
  name: 'restricted',
  path: '/restricted',
)
\@immutable
class RestrictedPageRoute extends GoRouteData {
  const RestrictedPageRoute();

  \@override
  Widget build(context, state) {
    return RestrictedPage();
  }
}
```


# Security in Mobile Apps


Mobile app security is a critical concern for developers and users alike. The [Open Web Application Security Project (OWASP)](https://owasp.org/) maintains industry-accepted mobile application security guidelines that should be followed when building multiplatform mobile applications.

:::danger
By far, the most common security threat is **social engineering**. Be sure to educate your team and create well-defined trust structures which require face-to-face confirmation for any proposed changes that affect security.
:::

## Common Mobile App Security Threats

- **Social Engineering**: is a manipulation tactic that exploits human error to gain unauthorized access to private information, systems, or valuables. In cybercrime, it involves deceiving users into revealing data, spreading malware, or granting access to restricted systems.

- **Malware**: Malicious software intentionally designed to harm, exploit, or compromise a mobile device, its data, or the user. Mobile app malware can take various forms, often disguised as legitimate apps or embedded within apps to deceive users into installing it on their devices.

  - Trojans
  - Spyware
  - Adware
  - Ransomware
  - Banking Malware
  - Keyloggers
  - Rooting/Jailbreaking Tools
  - Worms
  - Backdoors

- **Phishing**: a deceptive attempt by malicious actors to trick users into revealing sensitive information such as login credentials, financial details, or personal data through fraudulent means. Phishing typically relies on **social engineering techniques** to exploit user trust and **manipulate users into taking actions that compromise their security.**
- **Man in the middle attacks (MitM)**: intercepting communication between mobile apps and servers, allowing attackers to eavesdrop or modify data.
- **Data breaches:** Unauthorized access leads to the exposure of sensitive user data. Risks include personal information (PII), credentials, and financial data.
- **Authentication attacks**: attempts by malicious actors to exploit vulnerabilities in the app's authentication mechanisms to gain unauthorized access to user accounts, sensitive data, or application functionality. These attacks target flaws in how the app verifies the identity of its users or systems.
  - Credential Stuffing
  - Brute Force Attacks
  - Phishing Attacks
  - Session Hijacking
  - Man-in-the-Middle (MitM) Attacks
  - Password Reset Exploits
  - OAuth and Token-Based Attacks: Attackers exploit vulnerabilities in OAuth flows or misconfigure token handling to gain unauthorized access.
- **Code tampering**: Unauthorized modification of the mobile app's code, potentially leading to alterations in functionality or the injection of malicious code.
- **Reverse engineering**: Extraction of source code or sensitive information from the mobile app, often to create fake versions of the app.
- **Insufficient API Security**: Inadequate protection of APIs, leading to vulnerabilities such as unauthorized access, injection attacks, and data exposure.
- **Insecure Data Storage**: Weak encryption or improper storage of sensitive data on the device, making it vulnerable to unauthorized access.
- **Insufficient Transport Layer Protection:** Lack of proper TLS encryption during data transmission, exposing information to interception and manipulation.
- **Denial of Service (DoS) Attacks:** Overwhelming a mobile app or API with traffic disrupts its availability, causing service downtime.
- **Unsecured Third-Party Libraries:** Integration of insecure or outdated third-party libraries which introduce vulnerabilities into the mobile app.
- **Poorly Implemented Multi-Factor Authentication (MFA):** Inadequate implementation of MFA, allowing attackers to bypass additional authentication measures.
- **Supply Chain Attacks:** Compromising the security of a mobile app or API through vulnerabilities in its supply chain, including third-party services or components.

## OWASP Guidelines

The **Open Worldwide Application Security Project (OWASP)** is a globally recognized nonprofit organization dedicated to improving the security of software and web applications. Established in 2001, OWASP provides resources, tools, and best practices to help developers, organizations, and security professionals build secure applications and address vulnerabilities effectively.

### OWASP Mobile Top 10 Security Risks in 2024

The OWASP Mobile Top 10 is a list of the most critical security risks for mobile apps and is updated periodically to reflect emerging threats and trends.

The latest version, OWASP Mobile Top 10 2024, highlights the following risks:

![OWASP comparison 2016 vs 2024](./images/owasp_comparison.png)
_Source_: [OWASP Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/)

### Improper Credential Usage

Threat agents can exploit hardcoded credentials or improper credential usage in mobile applications by using automated tools, either publicly available or custom-built.

:::danger
If your app requires access to sensitive API's, **you must not include those API keys in the frontend of your app.**

It is impossible to secure any credentials that are shipped with an application, since **the compiled code for frontend applications is subject to reverse engineering** (no matter how clever you think you are).

Instead of shipping sensitive API keys in your app, create a microservice or cloud function which stores the API key securely in your backend (or leverage services like [Approov](https://approov.io/)). Yes, it's extra work — but it's mandatory for sensitive endpoints.
:::

:::tip

- Use the Android Keystore or iOS Keychain to store sensitive user information.
- Use strong encryption and hashing algorithms during credential storage and transmission.
- Avoid weak authentication mechanisms, including common/weak passwords or insecure authentication flows.
  :::

[Dart-crypt](https://github.com/hoylen/dart-crypt) allows you to salt and hash passwords easily.

[Firebase Authentication](https://firebase.google.com/docs/auth) handles a wide variety of common security considerations and eliminates the need for highly sophisticated authentication for small to mid-size projects.

There's also a [Flutter-specific guide to Auth0](https://developer.auth0.com/resources/guides/mobile/flutter/basic-authentication/) if you're leveraging that in your application.

For more information on _Improper Credential Usage_, [refer to the OWASP guide](https://owasp.org/www-project-mobile-top-10/2023-risks/m1-improper-credential-usage.html).

### Inadequate Supply Chain Security

Attackers can exploit vulnerabilities in the mobile app supply chain, such as inserting malicious code during development or exploiting flaws in third-party libraries, SDKs, or hardcoded credentials.

:::tip

- Leverage human-led code review (with automated tests, checks and analyzers).
- Ensure secure app signing and distribution to block malicious actors. Services like [Codemagic](https://codemagic.io/) can drastically simplify the code-signing process.
- Use trusted, validated third-party libraries to minimize risks.
- Implement a process that requires both a human and an automated vulnerability checker (such as dependabot) to review package updates and patches in your codebase.
- Stay up-to-date on supply chain incidents and open source package vulnerabilities.
- Carefully scan pull requests on your open source projects — many open source projects have accidentally merged malicious code by accident.
  :::

You can check the [Software supply chain security for Flutter and its ecosystem video](https://www.youtube.com/watch?v=7LFftXcw1jA) from the Flutter Forward 2023 conference.

The [**SLSA** (Supply Chain Levels for Software Artifacts) security framework](https://slsa.dev/) maintains a check-list of standards and controls to prevent supply chain attacks.

For more information on _Inadequate Supply Chain Security_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m2-inadequate-supply-chain-security.html)

### Insecure Authentication/Authorization

Threat agents that exploit authentication and authorization vulnerabilities typically do so through automated attacks that use available or custom-built tools.

:::tip

- Use server-side authentication.
- Encrypt local data.
- Use device-specific tokens instead of storing passwords or using weak identifiers.
- Make persistent authentication opt-in.
- Avoid weak PINs for passwords.
- Enforce all controls server-side; assume client-side can be bypassed.
- Use biometrics (FaceID, TouchID) for secure access to sensitive data.
- Perform local integrity checks if offline functionality is necessary.
  :::

For more on data safety, check out the [Encryption and Decryption in Flutter](https://medium.com/@laithalsahore19/explore-encrypt-decrypt-data-in-flutter-e1e64c86b0ee) overview.

You can also use [Local Auth](https://pub.dev/packages/local_auth) to integrate biometric authentication.

For more information on _Insecure Authentication/Authorization_, [refer to the OWASP guide](https://owasp.org/www-project-mobile-top-10/2023-risks/m3-insecure-authentication-authorization.html).

### Insufficient Input/Output Validation

Insufficient validation and sanitization of user inputs or network data in mobile apps can lead to critical vulnerabilities, including SQL injection, command injection, and XSS attacks.

:::tip

- Use strict input validation, set length limits, and reject unexpected or malicious input.
- Sanitize output to prevent XSS (cross-site scripting).
- Use parameterized queries to block SQL injection.
- Work with external security vendors which can evaluate and test your application and its servers.
  :::

Use the [Formz](https://pub.dev/packages/formz) package to validate forms in Flutter and prevent incorrect data to be sent to the backend.

For more information on _Insufficient Input/Output Validation_, [refer to the OWASP guide](https://owasp.org/www-project-mobile-top-10/2023-risks/m4-insufficient-input-output-validation.html).

### Insecure Communication

Threat agents can intercept or modify insecure communications transferred between an app and the server.

When creating an app, assume threats can originate from any of the following:

- Adversaries on the same local network (compromised Wi-Fi).
- Unauthorized network devices (malicious routers or proxy servers).
- Malware on the mobile device itself.

:::tip

- Use SSL/TLS for all data transmissions to backend services and third-party entities and avoid mixed SSL sessions.
- Only accept certificates signed by trusted certificate authorities (CA's) and never allow expired or mismatched certificates.
- Use current, industry accepted encryption algorithms with appropriate key lengths (AES-128 is a good start). Encryption algorithms are subject to mathematical analysis: some older algorithms have been identified by mathematicians and experts as being easier to exploit.
- Pin certificates and require SSL chain verification.
- Never transmit sensitive data via unencrypted channels (like SMS or via push notifications).
- During security testing, conduct traffic analysis to verify no plain text data transmissions.
  :::

If you're using Firebase, you can implement [Firebase App Check](https://firebase.google.com/docs/app-check) to protect your backend from unauthorized clients accessing it.

For more on certificates, see [SSL Certificate Pinning in Flutter](https://dwirandyh.medium.com/securing-your-flutter-app-by-adding-ssl-pinning-474722e38518).

You may also use a package called [Http Certificate Pinning package](https://pub.dev/packages/http_certificate_pinning) to add certificate pinning to your app.

For more information on _Insecure Communication_, [refer to the OWASP guide](https://owasp.org/www-project-mobile-top-10/2023-risks/m5-insecure-communication.html).

### Inadequate Privacy Controls

Privacy controls are concerned with protecting personally identifiable information (PII), such as names and addresses, credit card information, email and IP addresses, health information, religion, sexuality, and political opinions.

This information is valuable to attackers for a number of reasons. For example, an attacker could impersonate the victim to commit fraud, misuse the victim's payment details, blackmail the victim with sensitive information, or harm the victim by destroying or tampering with their critical data.

:::tip

- The best way to prevent privacy violations is to minimize the collection and processing of Personally Identifiable Information (PII). This requires a full understanding of the app's PII usage.
- Evaluate whether all personally identifiable information is necessary, whether less sensitive alternatives can be used, or whether personally identifiable information can be reduced, anonymized, or deleted after a certain period. Allow users to consent to the optional use of personally identifiable information with clear awareness of the associated risks.
- Store or transfer PII only when absolutely necessary, with strict authentication and authorization controls. Secure personal data, such as encrypting health information with device TPM keys to protect against sandbox bypasses.
- Threat modeling can identify the most likely privacy risks, focusing security efforts accordingly. Use static and dynamic security tools to uncover vulnerabilities like improper logging or accidental data leakage.
  :::

For more information on _Inadequate Privacy Controls_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m6-inadequate-privacy-controls.html)

### Insufficient Binary Protection

Attackers target app binaries to extract valuable secrets like API keys or cryptographic secrets, access critical business logic or pre-trained AI models, or investigate weaknesses in backend systems. They may also manipulate binaries to access paid features for free, bypass security checks, or insert malicious code. Repackaging attacks can exploit unsuspecting users, such as modifying payment identifiers and redistributing compromised apps to divert payments to attackers. Protecting app binaries is crucial to prevent data theft, fraud, and malicious exploitation.

:::tip

- Apps should only access the minimal information needed to function, as all data in the binary is vulnerable to leaks or manipulation.
- Use obfuscation tools to make binaries incomprehensible. Native compilation, interpreters, or nested virtual machines can further complicate reverse engineering Test obfuscation quality using reverse-engineering tools.
- Obfuscation makes skipping security checks harder. Reinforce local security checks through backend validation and implement integrity checks to detect code tampering, though attackers may still bypass local checks.
- Integrity checks at app launch can detect unauthorized modifications and redistribution. Violations can be reported to remove fake apps from stores, and specialized services are available to support detection and removal efforts.
  :::

Tools and services such as FreeRASP and Approov can help mitigate the likelihood of a compromised app binary or repackaging attack.

- [Approov](https://approov.io/docs/latest/approov-usage-documentation/)
- [FreeRASP](https://pub.dev/packages/freerasp)

This is a great article that talks about how to secure your API Keys.

- [Securing API Keys](https://nshipster.com/secrets/)
- [Obfuscating Dart Code](https://flutter.dev/docs/deployment/obfuscate)

:::caution
There is no such thing as perfect security against app repackaging attacks. API keys and secrets stored on the client side are always vulnerable to extraction through reverse engineering.

To protect sensitive API's, implement a custom-backend which acts as middleware between the app and the sensitive api's so that the API keys never reach the frontend.
:::

More information on _Insufficient Binary Protection_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m7-insufficient-binary-protection.html)

### Security Misconfiguration

Security misconfiguration occurs when mobile apps have improperly configured security settings, permissions, or controls, leading to vulnerabilities and unauthorized access. Threat agents, such as attackers with physical device access or malicious apps, exploit these weaknesses to access sensitive data or execute unauthorized actions within the vulnerable app's context. Proper configuration is crucial to mitigate these risks.

:::tip

- Ensure default settings do not expose sensitive data or unnecessary permissions.
- Do not use hardcoded credentials.
- Request only necessary permissions for the app's functionality.
- Encrypt app communications and implement certificate pinning.
- Turn off debugging features in production apps.
- Prevent app data from being included in device backups.
- Only export activities, content providers, and services that are required.
  :::

:::caution
Don't add permissions that are not necessary for the app to work. It's easy for an attacker to exploit these permissions to gain access to sensitive data.

In general, you want to respect the **principle of least privilege**: only request the permissions that are absolutely necessary for the app to function.
:::

For more information on _Security Misconfiguration_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m8-security-misconfiguration.html)

### Insecure Data Storage

Insecure data storage in mobile apps exposes sensitive information to various threat agents, including skilled attackers, malicious insiders, state-sponsored actors, cybercriminals, script kiddies, data brokers, competitors, and activists. These agents exploit vulnerabilities like weak encryption, insecure storage, and improper handling of credentials.

:::tip

- Employ robust encryption algorithms to protect data at rest and in transit, such as AES-256.
- Use secure communication protocols like HTTPS or SSL/TLS to protect data during transmission.
- Store sensitive data generated on-device in secure locations, such as Keychain on iOS or Keystore on Android to prevent unauthorized access.
- Use strong authentication, role-based access controls, and validate user permissions to limit access to sensitive data.
- Prevent injection attacks by validating and sanitizing user input to ensure only valid data is stored.
- Use secure session tokens, set proper session timeouts, and securely store session data.
- Keep all libraries and dependencies up to date and apply security patches promptly.
- Monitor security advisories and platform updates to address emerging threats and vulnerabilities.
  :::

If you are using Firestore to store your data, be sure to configure the relevant Firestore security rules for your application.

- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

For sensitive data generated on-device, use the **secure storage** package to store sensitive data in Flutter.

- [Secure Storage](https://pub.dev/packages/flutter_secure_storage)

For more information on _Insecure Data Storage_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m9-insecure-data-storage.html)

### Insufficient cryptography

Threat agents exploiting insecure cryptography in mobile apps aim to compromise the confidentiality, integrity, and authenticity of sensitive information. They include attackers targeting cryptographic algorithms or implementations to decrypt sensitive data, malicious insiders manipulating processes or exposing encryption keys, state-sponsored actors conducting cryptanalysis for intelligence gathering, cybercriminals exploiting weak encryption for data theft or financial fraud, and attackers leveraging vulnerabilities in cryptographic protocols or libraries. Mitigating these risks requires robust cryptographic practices and secure implementation.

:::tip

- Use strong and widely accepted encryption algorithms such as AES-256, RSA, or ECC, ensuring key lengths adhere to industry standards for strong cryptographic protection.
- Follow secure key management practices by storing keys securely in key vaults and making use of hardware security modules for trusted access.
- Encryption and decryption processes should utilize established, peer-reviewed libraries to avoid errors associated with custom implementations, as implementing cryptography correctly is incredibly difficult to do and new vulnerabilities are continually identified, even in major projects.
- Encryption keys must be securely stored using operating system-provided mechanisms or hardware-based options and should not be stored in plain text.
- Use secure transport protocols like HTTPS with proper certificate validation to protect data in transit.
- Validate and authenticate the integrity and authenticity of encryption processes using certificates or digital signatures. Regular updates to cryptographic components are essential to mitigate vulnerabilities, supported by security testing such as vulnerability assessments and penetration testing. Follow industry standards and best practices from organizations like NIST and IETF.
- Adopt strong hash functions like SHA-256 or bcrypt, apply salting to hashed passwords to defend against precomputed attack tables, and use _key derivation functions_ like _PBKDF2_ or _scrypt_ to strengthen password-based cryptography and harden your application against brute-force attacks.
  :::

Check out the following guides for hardening your app's cryptography:

- [Cryptography in Flutter](https://medium.com/flutterdevs/cryptography-in-flutter-7b3b1e3b3b3b)
- [Unlocking Secure Flutter Apps: A Guide to Building with Dart's Cryptography](https://30dayscoding.com/blog/building-flutter-apps-with-darts-cryptography)
- [Crypto Package](https://pub.dev/packages/crypto)

For more information on _Insufficient Cryptography_, [refer to the OWASP guide.](https://owasp.org/www-project-mobile-top-10/2023-risks/m10-insufficient-cryptography.html)

## OWASP MAS Checklist

The [**OWASP Mobile Application Security (MAS) Checklist**](https://mas.owasp.org/checklists/) is a comprehensive guide to securing mobile apps against common security threats. The checklist will provide you with a detailed list of security best practices, including secure coding guidelines, secure data storage, secure communication, and secure authentication mechanisms.

## Other OWASP Resources

- [OWASP Mobile Application Security Testing Guide (MASTG)](https://mas.owasp.org/MASTG/)
- [OWASP Mobile Application Security Verification Standard (MASVS)](https://mas.owasp.org/MASVS/)
- [OWASP Mobile Application Security Weakness Enumeration (MASWE)](https://mas.owasp.org/MASWE/)


# Bloc Event Transformers


Since [Bloc v.7.2.0](https://bloclibrary.dev/migration/#v720), events are handled concurrently by default. This allows event handler instances to execute simultaneously and provides no guarantees regarding the order of handler completion.

Concurrent event handling is often desirable, but issues ranging from performance degradation to serious data and behavior defects can emerge if your specified event transformer diverges from the needs of your state management system.

In particular, [race conditions](https://en.wikipedia.org/wiki/Race_condition) can produce bugs when the result of operations varies with their order of execution.

#### Registering Event Transformers

Event transformers are specified in the `transformer` field of the event registration functions in the `Bloc` constructor:

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc() : super(MyState()) {
    on<MyEvent>(
      _onEvent,
      transformer: mySequentialTransformer(),
    )
    on<MySecondEvent>(
      _onSecondEvent,
      transformer: mySequentialTransformer(),
    )
  }
}
```

Each `on<E>` statement creates a bucket for handling events of type `E`.

:::note
Note that event transformers are only applied within the bucket they are specified in. In the above example, only events of the same type (two of `MyEvent` or two `MySecondEvent`) would be processed sequentially, while a `MyEvent` and a `MySecondEvent` would be processed concurrently.
:::

If you would like to enforce a global transformer scheme across event types, Joanna May's article ["How to Use Bloc With Streams and Concurrency"](https://verygood.ventures/blog/how-to-use-bloc-with-streams-and-concurrency) provides a concise guide.

### Transformer Types

The [Bloc Event Transformer API](https://bloclibrary.dev/bloc-concepts/#advanced-event-transformations) allows you to implement custom event transformers, but the [`bloc_concurrency`](https://pub.dev/packages/bloc_concurrency) package furnishes several out-of-the box transformers which cover a wide range of use cases. These include:

- `concurrent` (default)
- `sequential`
- `droppable`
- `restartable`

Let's investigate the `sequential`, `droppable`, and `restartable` transformers and look at how they're used.

#### Sequential

The `sequential` transformer ensures that events are handled one at a time, in a first in, first out order from when they are received.

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc() : super(MyState()) {
    on<MyEvent>(
      _onEvent,
      transformer: sequential(),
    )
  }
}
```

To illustrate the utility of sequential event handling, suppose we're building a money-tracking app. The `_onChangeBalance` handler first calls an API to read our current account balance, and then sends a call to update the balance to its new value:

```dart
class MoneyBloc extends Bloc<MoneyEvent, MoneyState> {
  MoneyBloc() : super(MoneyState()) {
    on<ChangeBalance>(_onChangeBalance, transformer: concurrent());
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

We then quickly add two events `ChangeBalance(add: 20)` and `ChangeBalance(add: 40)`, which will be handled concurrently. A possible sequence of events is:

- The first `ChangeBalance` handler instance will read a balance of `$100`, and send a not-yet-received request to the API to update the balance to `$120`.
- Before the first handler finishes its execution, the second handler executes, reads the old account value of `$100`, and completes an API request to update the balance to `$140`.
- Finally, the first handler's call to update the balance reaches the API, and the balance is now overwritten to `$120`.

This example illustrates the issues that can arise from concurrent handling of operations. Had we used a `sequential` transformer for the `ChangeBalance` event handler and ensured that the first addition of $20 had completed before processing the next event, we wouldn't have lost $40.

Note that when operations are safe to execute concurrently, using a `sequential` transformer can introduce unnecessary latency into event handling.

#### Droppable

The `droppable` transformer will discard any events that are added while an event in that bucket is already being processed.

```dart
class SayHiBloc extends Bloc<SayHiEvent, SayHiState> {
  SayHiBloc() : super(SayHiState()) {
    on<SayHello>(
      _onSayHello,
      transformer: droppable(),
    )
  }

  Future<void> _onSayHello(
    SayHello event,
    Emitter<SayHiState> emit,
  ) async {
    await api.say("Hello!");
  }
}
```

In the above example, we'd like to avoid clogging up our API with unnecessary duplicate greetings. The `droppable` transformer will ensure that additional `SayHello` events added while the first `_onSayHello` instance is executing will be discarded and never executed.

Since events added during ongoing handling will be discarded by the `droppable` transformer, ensure that you're OK with any data stored in that event being lost.

#### Restartable

The `restartable` transformer inverts the behavior of `droppable`, halting execution of previous event handlers in order to process the most recently received event.

```dart
class ThoughtBloc extends Bloc<ThoughtEvent, ThoughtState> {
  ThoughtBloc() : super(ThoughtState()) {
    on<ThoughtEvent>(
      _onThought,
      transformer: restartable(),
    )
  }

  Future<void> _onThought(
    ThoughtEvent event,
    Emitter<ThoughtState> emit,
  ) async {
    await api.record(event.thought);
    emit(
      state.copyWith(
        message: 'This is my most recent thought: ${event.thought}',
      )
    );
  }
}
```

If we want to avoid emitting the declaration that `${event.thought}` is my most recent thought when the bloc has received an even more recent thought, the `restartable` transformer will suspend `_onThought`'s processing of the outdated event if a more recent event is received during its execution.

#### Testing Blocs

When writing tests for a bloc, you may encounter an issue where a variable event handling order is acceptable in use, but the inconsistent sequence of event execution makes the determined order of states required by `blocTest`'s `expect` field results in unpredictable test behavior:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) {
    bloc.add(ChangeValue(add: 1));
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

If the `ChangeValue(remove: 1)` event completes execution before `ChangeValue(add: 1)` has finished, the resultant states will instead be `MyState(value: -1),MyState(value: 0)`, causing the test to fail.

Utilizing a `await Future<void>.delayed(Duration.zero)` statement in the `act` function will ensure that the task queue is empty before additional events are added:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) {
    bloc.add(ChangeValue(add: 1));
    await Future<void>.delayed(Duration.zero);
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

### Conclusion

[`bloc_concurrency`](https://pub.dev/packages/bloc_concurrency) provides several event transformers to ensure that your bloc handles events in a manner that's conducive to the goals of your state management system. If `concurrent`, `sequential`, `droppable`, or `restartable` are insufficient for your purposes (for example if you would like a custom debouncing interval), you can always implement a custom [`EventTransformer`](https://bloclibrary.dev/bloc-concepts/#advanced-event-transformations)


# State Handling


To `enum` or to `sealed class`? That is the question we'll be discussing in this episode of **Very Good Engineering** 🦄, to understand which way to go when declaring states for our Cubits/Blocs.

> 💡 Either one of these options could be the right one depending on the following use cases.

## Do I want to persist previous data when emitting a new state?

As it happens when filling out a form where data is updated step by step, or when the state has several values that are loaded independently, if your aim is to update new fields of the state or the state itself without losing previously emitted data, using **a single class with an enum as the state's 'status'** it's the easiest way to go.

> 💡 You can also share properties throughout all the states by setting those inside the parent `sealed` or `abstract` class.

This can look something like:

```txt
initial state
        |----> update property 1
            |----> update property 2
                  |----> update property 3
                        |----> submit form
                                  |----> success state
                                  |----> failure state
```

Let's see an example:

```dart
enum CreateAccountStatus {
  initial,
  loading,
  success,
  failure,
}

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

  // Getter to check whether every field has valid data.
  bool get isValid => name.isNotNullOrEmpty
      && surname.isNotNullOrEmpty
      && email.isNotNullOrEmpty
      && email.isValid;

  \@override
  List<Object> get props => [
    status,
    name,
    surname,
    email,
  ];
}
```

As you can see above, because the user is going to fill out their name, surname, and email, and any of them can be null or empty at any time, we need to make sure we have data in each property as per our business logic before allowing the user to create their account.

> 💡 Using `enums` to handle status is useful in cases like this where there are **several steps** for the user to fill up information and the **data emitted in previous steps should not be lost in newer emits**.

Take a look at the `Cubit` example for this implementation:

```dart

class CreateAccountCubit extends Cubit<CreateAccountState> {
  CreateAccountCubit(): super(const CreateAccountState());

  void updateName(String name) {
    // We emit the name without losing any other data.
    emit(state.copyWith(name: name));
  }

  void updateSurname(String surname) {
    // We emit the surname without losing any other data.
    emit(state.copyWith(surname: surname));
  }

  void updateEmail(String email) {
    // We emit the email without losing any other data.
    emit(state.copyWith(email: email));
  }

  // ... other update methods here.

  Future<void> createAccount() async {
    emit(state.copyWith(status: CreateAccountStatus.loading));
    try {
      // Double check the current state is valid.
      if (state.isValid) {
        emit(state.copyWith(status: CreateAccountStatus.success));
      } else {
        emit(state.copyWith(status: CreateAccountStatus.failure));
      }
    } catch (e, s) {
      addError(e, s);
      // We can emit the failure without losing the content that
      // was added by the user.
      emit(state.copyWith(status: CreateAccountStatus.failure));
    }
  }
}
```

As you can see, having a **single state class** with an `enum` for the status helps to keep the information that was added previously.

Let's see how we consume these types of states in the UI using the `BlocListener` widget.

```dart
class CreateAccountPage extends StatelessWidget {
  const CreateAccountPage({super.key});

  \@override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BlocListener<CreateAccountCubit, CreateAccountState>(
        listener: (context, state) {
          // This is how we check for the actual status.
          if (state.status == CreateAccountStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: Colors.red,
                content: Text('Something went wrong')));
          }
          if (state.status == CreateAccountStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: Colors.green,
                content: Text('Account created!')));
          }
        },
        child: CreateAccountFormView(),
      ),
    );
  }
}
```

As seen above, with this approach, the current status comes from the `status` **enum** property inside the `cubit state`.

Let's now check the other way to handle states.

## Do I want to emit a _fresh_ state every time?

The other side of the state management aims for clean state updates, isolating the properties of each state that's emitted. This is useful for when the data being fetched is not going to change, or for instance, we don't need to keep it in future emits, and it's a matter of simply:

```txt
loading ---->   <try fetch data>    |----> success (data fetched)
                                    |----> failure
```

This can be achieved by leveraging the use of `sealed classes` (when in Flutter `3.13+`) or basic `abstract classes` (when in older Flutter versions).

### Using `sealed` classes

Let's see how the states are built:

```dart
// Using sealed classes.
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

As you can see, each state holds its own data, and it's properly isolated from one another.

Let's now see how to treat this state in the Cubit:

```dart
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileLoading()) {
    getProfileDetails();
  }

  Future<void> getProfileDetails() async {
    try {
      await Future.delayed(const Duration(seconds: 3), () {});

      final data = Profile(
        name: 'Pepe',
        surname: 'Martinez',
        email: 'pepe@gmail.com',
      );

      emit(ProfileSuccess(data));
    } catch (e) {
      // We can emit the failure without losing the content that was
      // added by the user.
      emit(ProfileFailure(
          'Oops, could not load your profile. Please try again later.'));
    }
  }
}
```

And now let's consume that `Cubit` from the UI:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  \@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProfileCubit, ProfileState>(builder: (context, state) {
        // Leverage the usage of switch statements.
        return switch (state) {
          ProfileLoading() => const _ProgressIndicator(),
          // 'success' here is the same state value casted as a ProfileSuccess.
          ProfileSuccess success => ProfileView(success.profile),
          // Here we get the message property from the ProfileFailure state.
          ProfileFailure(errorMessage: final message) => Text(message),
        };
      }),
    );
  }
}
```

As you can see, `sealed classes` helps us to properly **isolate** data inside each state, and whenever we check we are in a certain state **we are sure that the data won't be null at all**, as it happens when dealing with `enum states`.

### Using `abstract` classes

```dart
// Using abstract classes.
abstract class ProfileState {}

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

The `Cubit` class doesn't change at all:

```dart
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileLoading()) {
    getProfileDetails();
  }

  Future<void> getProfileDetails() async {
    try {
      await Future.delayed(const Duration(seconds: 3), () {});

      final data = Profile(
        name: 'Pepe',
        surname: 'Martinez',
        email: 'pepe@gmail.com',
      );

      emit(ProfileSuccess(data));
    } catch (e) {
      // We can emit the failure without losing the content that was
      // added by the user.
      emit(ProfileFailure(
          'Oops, could not load your profile. Please try again later.'));
    }
  }
}
```

But the way we consume **states** as `classes` differs:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  \@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (_, state) {
          // Using normal Switch statement.
          switch (state) {
            case ProfileLoading():
              return const _ProgressIndicator();
            case ProfileSuccess():
              // Properties have to be accessed by the state.
              return ProfileView(state.profile);
            case ProfileFailure():
              return Text(state.errorMessage);
            // Default case is mandatory.
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
```

Here you can see that consuming states based on an `abstract class` is more painful than using `sealed classes`, but is still the way to go when the Flutter version is not up-to date and you would like to isolate each state.

### Bonus - Share properties in some of the states (sealed or abstract classes)

You might be wondering... can I have the same property in more than one state and still continue to use sealed classes? **Yes you can!**

> 💡 You can also share properties throughout all the states by setting those inside the parent `sealed` or `abstract` class.

Let's look at an updated version of our state and cubit implementation using `sealed classes` (Pst! Same thing works for `abstract classes` as well):

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
```

As seen above, `ProfileSuccess` and `ProfileEditing` contains a `Profile` property inside. How can we handle that from inside the `Cubit`?

```dart
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileLoading()) {
    getProfileDetails();
  }

  Future<void> getProfileDetails() async {
    // Already seen.
  }

  Future<void> editName(String newName) async {
    switch(state) {
      // Here we get both Profile objects stored inside each state class
      // and we're able to use it inside the block to update the profile.
      case ProfileSuccess(profile: final prof):
      case ProfileEditing(profile: final prof):
        final newProfile = prof.copyWith(name: newName);
        emit(ProfileSuccess(newProfile));
      case ProfileLoading():
      case ProfileFailure():
        return;
    }
  }
}
```

This way you can be sure to handle all states in your Cubit methods and also be able to use the values contained.

To conclude this part, here's also the way to do the same thing but UI side:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  \@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProfileCubit, ProfileState>(builder: (context, state) {
        // Leverage the usage of switch statements.
        return switch (state) {
          ProfileLoading() => const _ProgressIndicator(),
          // We get the Profile prof by declaring a value based on the
          // internal property of the state.
          ProfileSuccess(profile: final prof)
          || ProfileEditing(profile: final prof) => ProfileView(prof),
          // Here we get the message property from the ProfileFailure state.
          ProfileFailure(errorMessage: var message) => Text(message),
        };
      }),
    );
  }
}
```

Hope this helps to get an idea about which route to take when designing states for your Cubits/Blocs.✨


# Testing Overview


import { FileTree, TabItem, Tabs } from "@astrojs/starlight/components";

At Very Good Ventures, our goal is to achieve 100% test coverage on all projects. Writing tests not only helps to reduce the number of bugs, but also encourages code to be written in a very clean, consistent, and maintainable way. While testing can initially add some additional time to the project, the trade-off is fewer bugs, higher confidence when shipping, and less time spent in QA cycles.

## Organize test files

Test files should be organized to match your project file structure.

This `my_package` library contains `models` and `widgets`. The `test` folder should copy this structure:

<FileTree>

- my_package/
  - lib/
    - models/
      - model_a.dart
      - model_b.dart
      - models.dart
    - widgets/
      - widget_1.dart
      - widget_2.dart
      - widgets.dart
  - test/
    ...

</FileTree>

<Tabs>
  <TabItem label="Good ✅">
    <FileTree>

        - test/
          - models/
            - model_a_test.dart
            - model_b_test.dart
          - widgets/
            - widget_1_test.dart
            - widget_2_test.dart

    </FileTree>

  </TabItem>

  <TabItem label="Bad ❗️">
    <FileTree>

      - test/
        - model_a_test.dart
        - model_b_test.dart
        - widgets_test.dart

    </FileTree>

  </TabItem>
</Tabs>

> Note: `models.dart` and `widgets.dart` are barrel files and do not need to be tested.

:::tip
You can automatically create or find a test file when using the [Flutter VS Code Extension](https://docs.flutter.dev/tools/vs-code) by right-clicking on the file within the [explorer view](https://code.visualstudio.com/docs/getstarted/userinterface#_explorer-view) and selecting "Go to Tests" or using the ["Go to Test/Implementation File"](https://github.com/Dart-Code/Dart-Code/blob/09cb9828b7b315d667ee5dc97e9287a6c6c8655a/package.json#L323) command within the [command palette](https://code.visualstudio.com/docs/getstarted/userinterface#_command-palette).
:::

:::note
You can find more information about package layouts in the [Dart Package layout conventions](https://dart.dev/tools/pub/package-layout) and in [What makes a package](https://dart.dev/guides/libraries/create-packages#what-makes-a-package).
:::

## Assert test results using expect or verify

All tests should have one or more statements at the end of the test asserting the test result using either an [expect](https://api.flutter.dev/flutter/flutter_test/expect.html) or [verify](https://pub.dev/documentation/mocktail/latest/).

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets('calls [onTap] on tapping widget', (tester) async {
      var isTapped = false;
      await tester.pumpWidget(
        SomeTappableWidget(
          onTap: () => isTapped = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(SomeTappableWidget());
      await tester.pumpAndSettle();

      expect(isTapped, isTrue);
    });
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('can tap widget', (tester) async {
      await tester.pumpWidget(SomeTappableWidget());
      await tester.pumpAndSettle();

      await tester.tap(SomeTappableWidget());
      await tester.pumpAndSettle();
    });
    ```

  </TabItem>
</Tabs>

The above test would pass coverage on `SomeTappableWidget`, and pass as long as no exception is thrown, but it doesn't really tell any valuable information about what the widget should do.

Now, we are explicitly testing that we have accessed the `onTap` property of `SomeTappableWidget`, which makes this test more valuable, because its behavior is also tested.

## Use matchers and expectations

[Matchers](https://api.flutter.dev/flutter/package-matcher_matcher/package-matcher_matcher-library.html) provides better messages in tests and should always be used in [expectations](https://api.flutter.dev/flutter/flutter_test/expect.html).

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    expect(name, equals('Hank'));
    expect(people, hasLength(3));
    expect(valid, isTrue);
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    expect(name, 'Hank');
    expect(people.length, 3);
    expect(valid, true);
    ```

  </TabItem>
</Tabs>

## Test with a single purpose

Aim to test one scenario per test. You might end up with more tests in the codebase, but this is preferred over creating one single test to cover several cases. This helps with readability and debugging failing tests.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets('renders $WidgetA', (tester) async {});
    testWidgets('renders $WidgetB', (tester) async {});
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('renders $WidgetA and $WidgetB', (tester) async {});
    ```

  </TabItem>
</Tabs>

## Test behavior, not properties

When testing, especially when testing widgets, we should test the behavior of the widget, not its properties. For example, write a test that verifies tapping a button triggers the correct action, but don't waste time verifying the button has the correct padding if it's a static number in the code.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets('navigates to settings when button is tapped', (tester) async {
      await tester.pumpWidget(MyApp());
      
      await tester.tap(find.byType(SettingsButton));
      await tester.pumpAndSettle();
      
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('displays error message when login fails', (tester) async {
      await tester.pumpWidget(LoginPage());

      await tester.enterText(find.byType(TextField), 'invalid@email.com');
      await tester.tap(find.byType(LoginButton));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsOneWidget);
    });
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('button has correct padding', (tester) async {
      await tester.pumpWidget(
        SettingsButton(
          padding: EdgeInsets.all(16),
        ),
      );
      
      final button = tester.widget<SettingsButton>(find.byType(SettingsButton));
      expect(button.padding, equals(EdgeInsets.all(16)));
    });

    testWidgets('text color is red', (tester) async {
      await tester.pumpWidget(ErrorText('Error'));

      final text = tester.widget<Text>(find.text('Error'));
      expect(text.style?.color, equals(Colors.red));
    });
    ```

  </TabItem>
</Tabs>

Of course, if the color of a widget changes based on state, that should be tested since you're testing the behavior of the widget. However, if it's a static color, it's better tested by [golden tests](/testing/golden_file_testing/) or visual QA.

## Split your tests by groups

Having multiple tests in a class could cause problems with readability. It is better to split your tests into groups:

- Widget tests: you could potentially group by "renders", "navigation", etc.
- Bloc tests: group by the name of the event.
- Repositories and clients: group by name of the method you are testing.

> Tip: If your test file starts to become unreadable or unmanageable, consider splitting the file
> that you are testing into smaller files.


# Best Practices


import { TabItem, Tabs } from "@astrojs/starlight/components";

These are some tips for writing the most effective and maintainable tests possible.

## Name tests descriptively

Don't be afraid of being verbose in your tests. Make sure everything is readable, which can make it easier to maintain over time.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets('renders $YourView', (tester) async {});
    testWidgets('renders $YourView for $YourState', (tester) async {});
    test('given an [input] is returning the [output] expected', () async {});
    blocTest<YourBloc, RecipeGeneratorState>('emits $StateA if ...',);
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('renders', (tester) async {});
    test('works', () async {});
    blocTest<YourBloc, RecipeGeneratorState>('emits',);
    ```

  </TabItem>
</Tabs>

## Tests should be named as natural sentences

Tests should be organized so they read as natural sentences when combined with their group names. The top-level group should be the class or entity being tested, and nested groups should represent specific methods or behaviors.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    group(ShoppingCart, () {
      group('addItem', () {
        test('increases item count', () {
          // ShoppingCart addItem increases item count
        });

        test('updates total price', () {
          // ShoppingCart addItem updates total price
        });
      });

      group('calculateTotal', () {
        test('returns sum of all item prices', () {
          // ShoppingCart calculateTotal returns sum of all item prices
        });

        test('returns zero when cart is empty', () {
          // ShoppingCart calculateTotal returns zero when cart is empty
        });
      });
    });
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    void main() {
       test('Validate calculateTotal returns total when cart is empty', () {
        // No need for "Validate" as it's implied a test is validating a behavior
       });

      test('ShoppingCart addItem increases item count', () {
        // No grouping structure - harder to organize and read
      });

      test('returns zero', () {
        // Missing context - what class and method is this testing?
      });

      group('total tests', () {
        test('works correctly', () {
          // Too vague and doesn't read naturally
        });
      });
    }
    ```

  </TabItem>
</Tabs>

## Use string expression with types

If you're referencing a type within a test description, use a [string expression](https://dart.dev/language/built-in-types#string) to ease renaming the type:

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets('renders $YourView', (tester) async {});
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('renders YourView', (tester) async {});
    ```

  </TabItem>
</Tabs>

If your [test](https://pub.dev/documentation/test/latest/test/test.html) or [group](https://pub.dev/documentation/test/latest/test/group.html) description only contains a type, consider omitting the string expression:

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    group(YourView, () {});
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    group('$YourView', () {});
    ```

  </TabItem>
</Tabs>

## Keep test setup inside a group

When running tests through the `very_good` CLI's optimization, all test files become a single file.

If test setup methods are outside of a group, those setups may cause side effects and make tests fail due to issues that wouldn't happen when running without the optimization.

In order to avoid such issues, refrain from adding `setUp` and `setUpAll` (as well as `tearDown` and `tearDownAll`) methods outside a group:

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    void main() {
      group(UserRepository, () {
        late ApiClient apiClient;

        setUp(() {
          apiClient = _MockApiClient();
          // mock api client methods...
        });

        // Tests...
      });
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    void main() {
      late ApiClient apiClient;

      setUp(() {
        apiClient = _MockApiClient();
        // mock api client methods...
      });

      group(UserRepository, () {
        // Tests...
      });
    }
    ```

  </TabItem>
</Tabs>

## Use private mocks

Developers may reuse mocks across different test files. This could lead to undesired behaviors in tests. For example, if you change the default values of a mock in one class, it could effect your test results in another. In order to avoid this, it is better to create private mocks for each test file.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    class _MockYourClass extends Mock implements YourClass {}
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    class MockYourClass extends Mock implements YourClass {}
    ```

  </TabItem>
</Tabs>

:::tip
The analyzer will warn you about unused private mocks (but not if they're public!) if the [`unused_element` diagnostic message](https://dart.dev/tools/diagnostic-messages?utm_source=dartdev&utm_medium=redir&utm_id=diagcode&utm_content=unused_element#unused_element) is not suppressed.
:::

:::tip
If you have the [Bloc VS Code extension](https://github.com/felangel/bloc/tree/master/extensions/vscode) installed, you can use the [`_mock` snippet](https://github.com/felangel/bloc/tree/master/extensions/vscode#bloc) to quickly create a private mock.
:::

## Use keys carefully

Although keys can be an easy way to look for a widget while testing, they tend to be harder to maintain, especially if we use hard-coded keys. Instead, we recommend finding a widget by its type.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    expect(find.byType(HomePage), findsOneWidget);
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    expect(find.byKey(Key('homePageKey')), findsOneWidget);
    ```

  </TabItem>
</Tabs>

## Shared mutable objects should be initialized per test

We should ensure that shared mutable objects are initialized per test. This avoids the possibility of tests affecting each other, which can lead to flaky tests due to unexpected failures during test parallelization or random ordering.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    void main() {
      group(_MySubject, () {
        late _MySubjectDependency myDependency;

        setUp(() {
          myDependency = _MySubjectDependency();
        });

        test('value starts at 0', () {
          // This test no longer assumes the order tests are run.
          final subject = _MySubject(myDependency);
          expect(subject.value, equals(0));
        });

        test('value can be increased', () {
          final subject = _MySubject(myDependency);

          subject.increase();

          expect(subject.value, equals(1));
        });
      });
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    class _MySubjectDependency {
      var value = 0;
    }

    class _MySubject {
      // Although the constructor is constant, it is mutable.
      const _MySubject(this._dependency);

      final _MySubjectDependency _dependency;

      get value => _dependency.value;

      void increase() => _dependency.value++;
    }

    void main() {
      group(_MySubject, () {
        final _MySubjectDependency myDependency = _MySubjectDependency();

        test('value starts at 0', () {
          // This test assumes the order tests are run.
          final subject = _MySubject(myDependency);
          expect(subject.value, equals(0));
        });

        test('value can be increased', () {
          final subject = _MySubject(myDependency);

          subject.increase();

          expect(subject.value, equals(1));
        });
      });
    }
    ```

  </TabItem>
</Tabs>

## Do not share state between tests

Tests should not share state between them to ensure they remain independent, reliable, and predictable.

When tests share state (such as relying on static members), the order that tests are executed in can cause inconsistent results. Implicitly sharing state between tests means that tests no longer exist in isolation and are influenced by each other. As a result, it can be difficult to identify the root cause of test failures.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    class _Counter {
      int value = 0;
      void increment() => value++;
      void decrement() => value--;
    }

    void main() {
      group(_Counter, () {
        late _Counter counter;

        setUp(() => counter = _Counter());

        test('increment', () {
          counter.increment();
          expect(counter.value, 1);
        });

        test('decrement', () {
          counter.decrement();
          expect(counter.value, -1);
        });
      });
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    class _Counter {
      int value = 0;
      void increment() => value++;
      void decrement() => value--;
    }

    void main() {
      group(_Counter, () {
        final _Counter counter = _Counter();

        test('increment', () {
          counter.increment();
          expect(counter.value, 1);
        });

        test('decrement', () {
          counter.decrement();
          // The expectation only succeeds when the previous test executes first.
          expect(counter.value, 0);
        });
      });
    }
    ```

  </TabItem>
</Tabs>

## Use random test ordering

Running tests in an arbitrary (random) order is a crucial practice to identify and eliminate flaky tests, specially during continuous integration.

Flaky tests are those that pass or fail inconsistently without changes to the codebase, often due to unintended dependencies between tests.

By running tests in random order, these hidden dependencies are more likely to be exposed, as any reliance on the order of test execution becomes clear when tests fail unexpectedly.

This practice ensures that tests do not share state or rely on the side effects of previous tests, leading to a more robust and reliable test suite. Overall, the tests become easier to trust and reduce debugging time caused by intermittent test failures.

<Tabs>
  <TabItem label="Good ✅">
    ```sh # Randomize test ordering using the --test-randomize-ordering-seed
    option flutter test --test-randomize-ordering-seed random dart test
    --test-randomize-ordering-seed random very_good test
    --test-randomize-ordering-seed random ```
  </TabItem>
</Tabs>

## Avoid using magic strings to tag tests

When [tagging tests](https://github.com/dart-lang/test/blob/master/pkgs/test/doc/configuration.md#configuring-tags), avoid using magic strings. Instead, use constants to tag tests. This helps to avoid typos and makes it easier to refactor.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets(
      'render matches golden file',
      tags: TestTag.golden,
      (WidgetTester tester) async {
        // ...
      },
    );
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets(
      'render matches golden file',
      tags: 'golden',
      (WidgetTester tester) async {
        // ...
      },
    );
    ```

  </TabItem>
</Tabs>

:::caution

[Dart 2.17](https://dart.dev/guides/whats-new#may-11-2022-2-17-release) introduced [enhanced enumerations](https://dart.dev/language/enums)
and [Dart 3.3](https://dart.dev/guides/whats-new#february-15-2024-3-3-release) introduced [extension types](https://dart.dev/language/extension-types). These could be used to declare the tags within arguments, however you will not be able to use the tags within the [`@Tags` annotation](https://pub.dev/documentation/test/latest/test/Tags-class.html).

Instead, define an abstract class to hold your tags:

```dart
/// Defined tags for tests.
///
/// Use these tags to group tests and run them separately.
///
/// Tags are defined within the `dart_test.yaml` file.
///
/// See also:
///
/// * [Dart Test Configuration documentation](https://github.com/dart-lang/test/blob/master/pkgs/test/doc/configuration.md)
abstract class TestTag {
  /// Tests that compare golden files.
  static const golden = 'golden';
}
```

:::


# Golden File Testing


import { TabItem, Tabs } from "@astrojs/starlight/components";

The term golden file refers to a master image that is considered the true rendering of a given widget, state, application, or other visual representation you have chosen to capture.

:::note
To learn more about Golden file testing refer to [Testing Fundamentals video about Using Golden Files to Verify Pixel-Perfect Widgets](https://www.youtube.com/watch?v=_G6GuxJF44Q&list=PLprI2satkVdFwpxo_bjFkCxXz5RluG8FY&index=22) or to the [Flutter matchesGoldenFile documentation](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html).
:::

## Tag golden tests

Golden tests should be tagged to make it easier to run them separately from other tests.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    testWidgets(
      'render matches golden file',
      tags: TestTag.golden,
      (WidgetTester tester) async {
        await tester.pumpWidget(MyWidget());

        await expectLater(
          find.byType(MyWidget),
          matchesGoldenFile('my_widget.png'),
        );
      },
    );
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    ```dart
    testWidgets('render matches golden file', (WidgetTester tester) async {
      await tester.pumpWidget(MyWidget());

      await expectLater(
        find.byType(MyWidget),
        matchesGoldenFile('my_widget.png'),
      );
    });
    ```

  </TabItem>
</Tabs>

:::tip
[You should avoid using magic strings to tag tests](../testing/#avoid-using-magic-strings-to-tag-test). Instead, use constants to tag tests. This helps to avoid typos and makes it easier to refactor.
:::

### Configure your golden test tag

To configure a golden test tag across multiple files (or an entire package), create a `dart_test.yaml` file and add the tag configuration:

```yaml
tags:
  golden:
    description: "Tests that compare golden files."
```

:::note
Learn more about all the `dart_test.yaml` configuration options in the [Dart Test Configuration documentation](https://github.com/dart-lang/test/blob/master/pkgs/test/doc/configuration.md).
:::

You can then run the tests with the tag `golden` in isolation, or quickly update
the golden files with the `--update-goldens` flag:

```bash
flutter test --tags golden # Run only golden tests
flutter test --tags golden --update-goldens # Update golden files
```


# Theming


import { TabItem, Tabs } from "@astrojs/starlight/components";

The theme plays a crucial role in defining the visual properties of an app, such as colors, typography, and other styling attributes. Inconsistencies within the theme can result in poor user experiences and potentially distort the intended design. Fortunately, Flutter offers a great design system that enables us to develop reusable and structured code that ensures a consistent theme.

:::note
Flutter uses [Material Design](https://docs.flutter.dev/ui/design/material) with [Material 3](https://m3.material.io/develop/flutter) enabled by default as of the Flutter 3.16 release.
:::

:::tip[Did you know?]
Not everyone in the community is happy about Material and Cupertino being baked into the framework. Check out these discussions:

- https://github.com/flutter/flutter/issues/101479
- https://github.com/flutter/flutter/issues/110195

:::

## Use ThemeData

By using `ThemeData`, widgets will inherit their styles automatically which is especially important for managing light/dark themes as it allows referencing the same token in widgets and removes the need for conditional logic.

<Tabs>
  <TabItem label="Bad ❗️">
    ```dart
    class BadWidget extends StatelessWidget {
      const BadWidget({super.key});

      \@override
      Widget build(BuildContext context) {
        return ColoredBox(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.black,
          child: Text(
            'Bad',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        );
      }
    }
    ```

  </TabItem>
</Tabs>

The above widget might match the design and visually look fine, but if you continue this structure, any design updates could result in you changing a bunch of files instead of just one.

<Tabs>
  <TabItem label="Good ✅">
    ```dart
    class GoodWidget extends StatelessWidget {
      const GoodWidget({super.key});

      \@override
      Widget build(BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return ColoredBox(
          color: colorScheme.surface,
          child: Text(
            'Good',
            style: textTheme.bodyLarge,
          ),
        );
      }
    }
    ```

  </TabItem>
</Tabs>

Now, we are using `ThemeData` to get the `ColorScheme` and `TextTheme` so that any design update will automatically reference the correct value.

## Avoid Conditional Logic

It's generally recommended to steer clear of using conditional logic in UI for theming. This approach can complicate testing and make the code less readable. By leveraging Flutter's built-in design system, your app can have cleaner, more maintainable code that ensures consistent styling.

## Typography

Implementing typography is generally straightforward, but it's also easy to make mistakes, such as forgetting to adjust `TextStyle` attributes like `height` or resorting to hardcoded values instead of utilizing `TextTheme`.

Let's break down typography into three sections:

1. [Importing Fonts](#importing-fonts)
2. [Custom Text Styles](#custom-text-styles)
3. [TextTheme](#texttheme)

### Importing Fonts

To keep things organized, fonts are generally stored in an `assets` folder:

```txt
assets/
  |- fonts/
  |   - Inter-Bold.ttf
  |   - Inter-Regular.ttf
  |   - Inter-Light.ttf
```

Then declared in the `pubspec.yaml` file:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Light.ttf
          weight: 300
```

At this point, the font is imported and ready to use. However, to ensure type safety, we recommend using [flutter_gen](https://pub.dev/packages/flutter_gen) to generate code for our font. Here's an example what that generated code might look like:

```dart
/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

class FontFamily {
  FontFamily._();

  /// Font family: Inter
  static const String inter = 'Inter';
}
```

### Custom Text Styles

Whether importing a custom font or using the default one, it's a good idea to create a custom class for your text styles to maintain consistency and simplify updates across your app. Let's take a look at this example:

```dart
abstract class AppTextStyle {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
}
```

With this setup, any updates to the style are centralized which reduces the need to find it in multiple locations.

### TextTheme

The last step to implement typography is to update the [TextTheme](https://api.flutter.dev/flutter/material/TextTheme-class.html). Both `TextTheme` and [Custom Text Styles](#custom-text-styles) serve important roles but cater to different aspects of text styling. The benefit of using `TextTheme` is the seamless integration into `ThemeData` that allows for consistent application of text styles across widgets that use the current theme.

Here's a basic example:

```dart
ThemeData(
  textTheme: TextTheme(
    titleLarge: AppTextStyle.titleLarge,
  ),
),
```

Widgets can now reference the text style through `ThemeData`:

```dart
class TitleWidget extends StatelessWidget {
  const TitleWidget({super.key});

  \@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Text(
      'Title',
      style: textTheme.titleLarge,
    );
  }
}
```

## Colors

Based on the [Material 3 color system](https://m3.material.io/styles/color/system/overview), Flutter offers a [`ColorScheme`](https://api.flutter.dev/flutter/material/ColorScheme-class.html) class that includes a set of 45 colors, which can be utilized to configure the color properties of most components. Instead of using an absolute color such as `Colors.blue` or `Color(0xFF42A5F5)`, we recommend using [`Theme.of`](https://api.flutter.dev/flutter/material/Theme/of.html) to access the local `ColorScheme`. This `ColorScheme` can be configured within [`ThemeData`](#use-themedata) using a custom colors class such as `AppColors`.

### Custom Colors

Whether using default [Material Colors](https://api.flutter.dev/flutter/material/Colors-class.html) or custom ones, we recommend creating a custom class for your colors for easy access and consistency.

```dart
abstract class AppColors {
  static const primaryColor = Color(0xFF4F46E5);
  static const secondaryColor = Color(0xFF9C27B0);
}
```

### ColorScheme

Once we have a custom class for colors, update the `ColorScheme`:

```dart
ThemeData(
  colorScheme: ColorScheme(
    primary: AppColors.primaryColor,
    secondary: AppColors.secondaryColor,
  ),
),
```

Now widgets referencing those tokens will use the colors defined in `AppColors`, ensuring consistency across the app.

## Component Theming

Flutter provides a variety of [Material component widgets](https://docs.flutter.dev/ui/widgets/material) that implement the Material 3 design specification.
Material components primarily rely on the [`colorScheme`](https://api.flutter.dev/flutter/material/ThemeData/colorScheme.html) and [`textTheme`](https://api.flutter.dev/flutter/material/ThemeData/textTheme.html) for their styling, but each widget also has its own customizable theme as part of [`ThemeData`](https://api.flutter.dev/flutter/material/ThemeData-class.html).

For instance, if we want all [`FilledButton`](https://api.flutter.dev/flutter/material/FilledButton-class.html) widgets to have a minimum width of `72`, we can use [`FilledButtonThemeData`](https://api.flutter.dev/flutter/material/FilledButtonThemeData-class.html):

```dart
ThemeData(
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(72, 0),
    ),
  ),
),
```

We recommend leveraging component theming to customize widgets whenever possible, rather than applying customizations directly within each widget's code. Centralizing these customizations in `ThemeData` will help your widgets [avoid conditional logic](#avoid-conditional-logic) and ensure theming consistency in your app.

## Spacing

Spacing is one of the most important aspects of theming and design. If the UI is created without intentional spacing, users are likely to have a bad experience as the content of the app may be overwhelming and hard to navigate. Good designs will generally follow a spacing system using a base unit to simplify the creation of page layouts and UI.

Just as [custom text styles](#custom-text-styles) and [custom colors](#custom-colors) can be centralized in a class, spacing can also follow this setup:

```dart
abstract class AppSpacing {
  static const double spaceUnit = 16;
  static const double xs = 0.375 * spaceUnit;
  static const double sm = 0.5 * spaceUnit;
  static const double md = 0.75 * spaceUnit;
  static const double lg = spaceUnit;
}
```

Now, anytime spacing needs to be added to a widget, you can reference this class to ensure consistency and avoid hardcoded values.


# Widgets


import { TabItem, Tabs } from "@astrojs/starlight/components";

Widgets are the reusable building blocks of your app's user interface. It is important to design them to be readable, maintainable, performant, and testable. By following these principles, you can ensure a smooth development process and a high-quality user experience.

## Page/Views

Each page should be composed of two classes: a `Page`, which is responsible for defining the page's route and gathering all the dependencies needed from the context; and a `View`, where the "real" implementation of the UI resides.

Distinguishing between a `Page` and its `View` allows the `Page` to provide dependencies to the `View`, enabling the view's dependencies to be mocked when testing.

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  \@override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authenticationRepository =
            context.read<AuthenticationRepository>();
        return LoginBloc(
          authenticationRepository: authenticationRepository,
        );
      },
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  @visibleForTesting
  const LoginView({super.key});

  \@override
  Widget build(BuildContext context) {
    // omitted
  }
}
```

We can easily write tests for the `LoginView` by mocking the `LoginBloc` and providing it directly to the view.

:::note
The constructor of the `LoginView` is marked as `visibleForTesting`. This is necessary so that we can ensure that the view will not be used except via its page. This way, developers will not accidentally import and use the view without the injected dependencies provided by the page.
:::

```dart
class _MockLoginBloc extends MockBloc<LoginBloc, LoginState>
  implements LoginBloc {}

void main() {
  group('LoginView', () {
    late LoginBloc loginBloc;

    setUp(() {
      loginBloc = _MockLoginBloc();
    });

    testWidgets('renders correctly', (tester) async {
      await tester.pumpApp(
        BlocProvider<LoginBloc>.value(
          value: loginBloc,
          child: LoginView(),
        ),
      );

      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('when on state A, render X', (tester) async {
      await tester.pumpApp(
        BlocProvider<LoginBloc>.value(
          value: loginBloc,
          child: LoginView(),
        ),
      );

      expect(find.byType(X), findsOneWidget);
    });
  });
}
```

## Use standalone Widgets over helper methods

If a Widget starts growing with complexity, you might want to split the build method up. Instead of creating a function, simply create a new Widget.

<Tabs>
  <TabItem label="Good ✅">
    The recommended approach is to create an entirely separate class for your widget.

    ```dart
    class MyWidget extends StatelessWidget {
      const MyWidget({super.key});

      \@override
      Widget build(BuildContext context) {
        return const MyText('Hello World!');
      }
    }

    class MyText extends StatelessWidget {
      const MyText(this.text, {super.key});

      final String text;

      \@override
      Widget build(BuildContext context) {
        return Text(text);
      }
    }
    ```

  </TabItem>
  <TabItem label="Bad ❗️">
    Avoid creating a method that returns a widget.

    ```dart
    class MyWidget extends StatelessWidget {
      const MyWidget({super.key});

      \@override
      Widget build(BuildContext context) {
        return _getText('Hello World!');
      }

      Text _getText(String text) {
        return Text(text);
      }
    }
    ```

  </TabItem>
</Tabs>

### Why Create a New Widget?

Creating a new widget provides several benefits over using a helper method:

- Testability: You can write widget tests for the `MyText` widget without worrying about `MyWidget` or any of the dependencies that it might require.
- Maintainability: Smaller widgets are easier to maintain and aren't coupled to their parent widget. These widgets will also have their own BuildContext, so you don't have to worry about using the wrong or an invalid context.
- Reusability: Creating new widgets allows you to easily reuse the widget to compose larger widgets.
- Performance: Using a helper method to return a widget that could update the state could cause unnecessary rebuilds of the entire widget. Imagine that the `Text` widget triggered an animation when tapped. We would need to call `setState()`, which would rebuild `MyWidget` and all of its children. If this functionality were encapsulated in the `MyText` widget, only the `MyText` widget would be rebuilt when the `Text` is tapped.

The Flutter team has released a great [YouTube video](https://www.youtube.com/watch?v=IOyq-eTRhvo) about this topic.

Here are some more great resources on this subject:

- [Controlling build cost](https://flutter.dev/docs/perf/rendering/best-practices#controlling-build-cost)
- [Splitting widgets to methods is a performance anti-pattern](https://medium.com/flutter-community/splitting-widgets-to-methods-is-a-performance-antipattern-16aa3fb4026c)


# Layouts


import { Aside, Code, TabItem, Tabs } from "@astrojs/starlight/components";
import crossAxisAlignCenter from "assets/Cross Axis Align Center.png";
import crossAxisAlignEnd from "assets/Cross Axis Align End.png";
import crossAxisAlignStart from "assets/Cross Axis Align Start.png";
import crossAxisAlignStretch from "assets/Cross Axis Align Stretch.png";
import expanded from "assets/Expanded.png";
import flexible from "assets/Flexible.png";
import listview from "assets/Listview.png";
import mainAxisAlignCenter from "assets/Main Axis Alignment Center.png";
import mainAxisAlignEnd from "assets/Main Axis Alignment End.png";
import mainAxisAlignSpaceAround from "assets/Main Axis Alignment SpaceAround.png";
import mainAxisAlignSpaceBetween from "assets/Main Axis Alignment SpaceBetween.png";
import mainAxisAlignSpaceEven from "assets/Main Axis Alignment SpaceEvenly.png";
import mainAxisAlignStart from "assets/Main Axis Alignment Start.png";
import mainAxisMax from "assets/Main Axis Size Max.png";
import mainAxisMin from "assets/Main Axis Size Min.png";
import noConstraints from "assets/No Constraints.png";
import noFlex from "assets/No Flex.png";
import noSize from "assets/No Size.png";
import overflow from "assets/Overflow.png";
import parentSize from "assets/Parent Size.png";
import singleChildScroll from "assets/Single Child Scroll.png";
import spacer from "assets/Spacer.png";
import wrap from "assets/Wrap.png";
import yesConstraints from "assets/Yes Constraints.png";
import yesFlex from "assets/Yes Flex.png";
import yesSize from "assets/Yes Size.png";
import { Image } from "astro:assets";
import Column from "~/components/two_column.astro";

The Flutter [documentation](https://docs.flutter.dev/ui/layout) provides a great introduction to widget layout. Here, we will cover more detailed use cases with `Row`, `Column`, and `Listview`, specifically focusing on how to best leverage the sizing capabilities of widgets. For this discussion, we will illustrate techniques by using the following box widget — a blue square with rounded edges and padding.

```dart
class Box extends StatelessWidget {
  const Box({super.key});
  \@override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: 100,
      margin: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    );
  }
}
```

<Aside>
  The padding is added to assist with visualization as columns or rows will not
  add padding around or between children by default. In reality widgets will be
  right up next to each other.
</Aside>

## Why Indefinite Sizes

In an ideal world, every phone would have the same physical size and resolution. We could give each widget a width and a height that match the design, pixel for pixel. Unfortunately, there are countless number of screen sizes for all kinds of devices, so our code has to intelligently use the space to make designs looks consistent across multiple devices.

## Rows and Columns

`Row` and `Column` are the building blocks of all layouts and allow you to lay out a list of widgets in a particular direction — horizontally for rows and vertically for columns. Rows and columns provide three options to help with laying out across their children: `MainAxisSize`, `MainAxisAlignment`, and `CrossAxisAlignment`.

### `MainAxisSize`

`MainAxisSize` determines whether a `Row` or `Column` will fill the space in the main axis direction. By default, this is set to main `MainAxisSize.max`, meaning the height will be as large as possible (subject to height constraints). If set to `MainAxisSize.min`, the column height will shrink so as to only fit its children.

<Tabs>
  <TabItem label="min">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisMin} alt="An example of using MainAxisSize.min" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="max">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisMax} alt="An example of using MainAxisSize.max" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

### `MainAxisAlignment`

`MainAxisAlignment` determines how to lay out the children along the primary axis (vertical for columns and horizontal for rows) when there is extra vertical space available. If there is no extra vertical space, this value will do nothing.

<Tabs>
  <TabItem label="start">
    <Column>
      <div slot="left">
      
        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisAlignStart} alt="An example of using MainAxisAlignment.start" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="end">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisAlignEnd} alt="An example of using MainAxisAlignment.end" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="center">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisAlignCenter} alt="An example of using MainAxisAlignment.center" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="spaceAround">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisAlignSpaceAround} alt="An example of using MainAxisAlignment.spaceAround" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="spaceBetween">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={mainAxisAlignSpaceBetween} alt="An example of using MainAxisAlignment.spaceBetween" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="spaceEvenly">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
      ```

      </div>
      <Image src={mainAxisAlignSpaceEven} alt="An example of using MainAxisAlignment.spaceEvenly" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

### `CrossAxisAlignment`

`CrossAxisAlignment` determines how to lay out widgets along the alternate axis (vertically for rows and horizontally for columns). The column's width is set to the size of the largest child (by default). If all the children are the same size and there are no width constraints, this value will do nothing. While `start`, `center`, and `end` will only adjust the position of the widget, `stretch` will adjust the size of the widgets in the column.

<Aside>
  For these examples, the width of the parent container is set larger than the
  children.
</Aside>

<Tabs>
  <TabItem label="start">
    <Column>
      <div slot="left">

        ```dart
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={crossAxisAlignStart} alt="An example of using CrossAxisAlignment.start" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="end">
    <Column>
      <div slot="left">

        ```dart
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={crossAxisAlignEnd} alt="An example of using CrossAxisAlignment.end" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="center">
    <Column>
      <div slot="left">

        ```dart
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={crossAxisAlignCenter} alt="An example of using CrossAxisAlignment.center" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="stretch">
    <Column>
      <div slot="left">

        ```dart
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={crossAxisAlignStretch} alt="An example of using CrossAxisAlignment.stretch" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

## `Expanded`, `Flexible`, and `Spacer`

Within a row or column, you may want different widgets to take up differing amounts of space. `Expanded`, `Flexible`, and `Spacer` widgets are useful for customizing the sizes and positioning of child widgets. These widgets will wrap one of the children in a `Row` or `Column`.

<Aside>
  Using `Expanded` and `Spacer` will override `MainAxisAlignment` and
  `MainAxisSize`, as the extra space will be taken by the expanded widgets
  (which expand to take up all the available space, naturally).
</Aside>

### `Expanded`

The `Expanded` widget will cause its child widget to expand to fill all the available space across the main axis of its parent widget.

<Column>
  <div slot="left">

    ```dart
    Column(
      children: [
        Expanded(child: Box()),
        Box(),
        Box(),
        Box(),
      ],
    ),
    ```

  </div>
  <Image src={expanded} alt="An example of using Expanded" height="500" slot="right"/>
</Column>

### `Spacer`

The `Spacer` widget creates an empty space that fills all the available space across the main axis of its parent widget.

<Column>
  <div slot="left">

    ```dart
    Column(
      children: [
        Box(),
        Box(),
        Spacer(),
        Box(),
        Box(),
      ],
    ),
    ```

  </div>
  <Image src={spacer} alt="An example of using Spacer" height="500" slot="right"/>
</Column>

### `Flexible`

The `Flexible` widget is a more flexible (pun intended) expanded widget that lets you choose wether to fill the expandable space (or not).

<Column>
  <div slot="left">

    ```dart
    Column(
      children: [
        Flexible(fit: FlexFit.loose, child: Box()),
        Flexible(fit: FlexFit.tight, child: Box()),
        Box(),
        Box(),
      ],
    ),
    ```

  </div>
  <Image src={flexible} alt="An example of using Flexible" height="500" slot="right"/>
</Column>

### Flex Factor

`Expanded`, `Flexible`, and `Spacer` all have a `flex` factor parameter. The `flex` factor specifies a relative size compared to other widgets which also have a flex factor in the same row or column. By default, `Expanded`, `Flexible`, and `Spacer` each have a `flex` factor of `1.0`. If two widgets have a flex of 1, then they are they same size. If one has flex 4, then it will be 4 times bigger than the other. You can use flex factor to size widgets in the column in relation to each other. These widgets are meant used in a `Row` or `Column` so that all of the sizing will be done along the desired main axis.

<Tabs>
  <TabItem label="without flex">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Box()),
            Box(),
            Spacer(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={noFlex} alt="An example of not using a flex factor" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="with flex">
    <Column>
      <div slot="left">

        ```dart
        Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(flex: 4, child: Box()),
            Box(),
            Spacer(flex: 1),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={yesFlex} alt="An example of using a flex factor" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

## Rules for Parents and Children

To really understand how widgets are laid out, it helps to understand the relation between parents, their children, and the constraints and sizes set by each of them. The golden rule for layouts is as follows:

> Constraints go down. Sizes go up. Parent sets position. — Flutter, [Understanding Constraints](https://docs.flutter.dev/ui/layout/constraints)

### Constraints Go Down

Constraints that are set by the parent are enforced on the child widgets. If the parent sets a specific size, the child can only expand to fill the space set by the parent.

<Tabs>
  <TabItem label="without constraints">
    <Column>
      <div slot="left">
      
        ```dart
        Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Box(),
              Box(),
              Box(),
              Box(),
            ],
          ),
        ),
        ```

      </div>
      <Image src={noConstraints} alt="An example of not using constraints" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="with constraints">
    <Column>
      <div slot="left">

        ```dart
        Container(
          width: 300,
          height: 500,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Box(),
              Box(),
              Box(),
              Box(),
            ],
          ),
        ),
        ```

      </div>
      <Image src={yesConstraints} alt="An example of using constraints" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

### Sizes Go up

Children set their sizes within parents, but they cannot override any constraints provided by their parent.

<Tabs>
  <TabItem label="no size">
    <Column>
      <div slot="left">

        ```dart
        Container(
          child: Column(
            children: [
              Box(),
              Box(),
              Box(),
              Box(),
            ],
          ),
        ),
        ```

      </div>
      <Image src={noSize} alt="An example of not using sizes" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="children size">
    <Column>
      <div slot="left">

        ```dart
        Column(
          children: [
            Container(
              height: 100,
              width: 300,
              color: Colors.redAccent,
            ),
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={yesSize} alt="An example of using children's sizes" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="parents size">
    <Column>
      <div slot="left">

        ```dart
        Container(
          width: 200,
          child: Column(
            children: [
              Container(
                height: 100,
                width: 300,
                color: Colors.redAccent,
              ),
              Box(),
              Box(),
              Box(),
              Box(),
            ],
          ),
        ),
        ```

      </div>
      <Image src={parentSize} alt="An example of using parents sizes" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

### Parent Sets Position

Children do not know their absolute position since their position is set by the parent. Consider how the `Column` widget parameters `MainAxisAlignment` and `CrossAxisAlignment` set where the children are in the Column.

Flutter documentation also provides a number of detailed guides regarding constraints[^1] [^2] [^3].

## Wrapping and Scrolling

Sometimes a list of widgets will grow larger than the space that exists for it. When that happens inside a row or column, you will have _overflow_. The flutter library solves this by allowing you to make the items _wrap_ or _scroll_.

<Aside>
  Be careful when using widgets which try to fill all the available space, like
  `Expanded`, `Spacer`, etc, inside a `Wrap` or `Listview`. Since the `Wrap` and
  `Listview` don't constrain the sizes of their children (without additional
  configuration), you can end up with unbounded sizes and overflow errors.
</Aside>

### Wrap

The `Wrap` widget functions like a `Row` or `Column` depending on how you set the `direction` property. When the `Wrap` widget lays out its children widgets, the widgets will wrap to the next row or column when the end of one row or column has been reached.

The `Wrap` widget has several properties that are reminiscent of rows and columns. The `alignment` and `crossAxisAlignment` properties are equivalent to `mainAxisAlignment` and `crossAxisAlignment`, respectively. `Wrap` also provides extra properties to deal with additional rows that are created by the wrapping effect, like `runAlignment` and `runSpacing`.

### Listview

`Listview` will make a scrollable list for its children that scrolls in the direction specified by its `scrollDirection`. By default, the listview will expand in both the width and height directions, regardless of the specified direction `scrollDirection`.

The `shrinkwrap` parameter changes this: when true, the listview’s children will take up the least amount of space available as the listview will bound it's size in the primary direction to the size of those children. If the children take up more space than is available, the `shrinkwrap` property has no effect. The listview also provides many other properties to control scrolling and catching.

### SingleChildScrollView

A `SingleChildScrollView` will wrap a widget and make it scrollable. It is ideal to use when making other types of widgets (besides `Row` and `Column`) scrollable. When trying to render a list of children, however, it is usually more performant to use a listview over a `SingleChildScrollView`.

<Tabs>
  <TabItem label="overflow">
    <Column>
      <div slot="left">

        ```dart
        Column(
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={overflow} alt="An example of overflowing widgets" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="Wrap">
    <Column>
      <div slot="left">

        ```dart
        Wrap(
          direction: Axis.vertical,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={wrap} alt="An example of using wrap" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="Listview">
    <Column>
      <div slot="left">

        ```dart
        ListView(
          scrollDirection: Axis.vertical,
          children: [
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
            Box(),
          ],
        ),
        ```

      </div>
      <Image src={listview} alt="An example of using a listview" height="500" slot="right"/>
    </Column>

  </TabItem>
  <TabItem label="SingleChildScrollView">
    <Column>
      <div slot="left">

        ```dart
        SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              Box(),
              Box(),
              Box(),
              Box(),
              Box(),
              Box(),
              Box(),
              Box(),
            ],
          ),
        )
        ```

      </div>
      <Image src={singleChildScroll} alt="An example of using a SingleChildScrollView" height="500" slot="right"/>
    </Column>

  </TabItem>
</Tabs>

## Nesting

A layout will likely have many nested rows and columns. There is no limit to how many rows and columns can be nested, but it is important to consider the constraints that are present on the rows and columns when nesting these widgets. This is especially true when nesting scrollable widgets or using expanded widgets in a nested row or column.

<Aside type="tip" title="Do's">
  - Freely nest rows and columns (they are not expensive widgets) - On all rows
  and columns, consider what `mainAxisSize` should be (`min` or `max`) - Set
  `shrinkwrap` to `true` when nesting Listviews - Use widget inspector to
  visualize widget bounds to see how the widget hierarchy is being rendered -
  Consider if row or column might overflow on smaller devices
</Aside>

<Aside type="danger" title="Dont's">
  - Don't put `Expanded` widgets inside of `Wrap`, `Listview`, and
  `SingleChildScrollView`, even if nested (unless the nested value has a fixed
  size) - Don't use `SingleChildScrollView` when it is possible to use a regular
  listview (for the sake of performance).
</Aside>

[^1]: [Understanding Constraints](https://docs.flutter.dev/ui/layout/constraints)
[^2]: [`Row` class](https://api.flutter.dev/flutter/widgets/Row-class.html)
[^3]: [`BoxConstraints` class](https://api.flutter.dev/flutter/rendering/BoxConstraints-class.html)


