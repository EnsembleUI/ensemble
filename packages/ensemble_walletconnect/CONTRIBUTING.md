# Contributing to walletconnect-dart-sdk

👍🎉 First off, thanks for taking the time to contribute! 🎉👍

The following is a set of guidelines for contributing to walletconnect-dart-sdk.
These are mostly guidelines, not rules. Use your best judgment,
and feel free to propose changes to this document in a pull request.

## Proposing a Change

If you intend to change the public API, or make any non-trivial changes
to the implementation, we recommend filing an issue.
This lets us reach an agreement on your proposal before you put significant
effort into it.

If you’re only fixing a bug, it’s fine to submit a pull request right away
but we still recommend to file an issue detailing what you’re fixing.
This is helpful in case we don’t accept that specific fix but want to keep
track of the issue.

## Creating a Pull Request

Before creating a pull request please:

1. Fork the repository and create your branch from `master`.
1. Install all dependencies (`flutter packages get` or `pub get`).
1. Squash your commits and ensure you have a meaningful commit message.
1. If you’ve fixed a bug or added code that should be tested, add tests!
Pull Requests without 100% test coverage will not be approved.
1. Ensure the test suite passes.
1. If you've changed the public API, make sure to update/add documentation.
1. Format your code (`dartfmt -w .`).
1. Analyze your code (`dartanalyzer --fatal-infos --fatal-warnings .`).
1. Create the Pull Request.
1. Verify that all status checks are passing.

While the prerequisites above must be satisfied prior to having your
pull request reviewed, the reviewer(s) may ask you to complete additional
design work, tests, or other changes before your pull request can be ultimately
accepted.

## Adding an example

Examples live in the `examples` folder.

- For a Flutter example, add it to the `folder` list in the `examples-flutter`
step.
- For a web example, add it to the `folder` list in the `examples-web` step.
- For a pure Dart example, add it to the `folder` list in the `examples-pure`
step.

## Getting in Touch

If you want to just ask a question or get feedback on an idea you can post it
on Discord.

## License

By contributing to walletconnect-dart-sdk, you agree that your contributions will be licensed
under its [MIT license](LICENSE).

## Releasing a new version

To release a new version, you need to:

1. Bump the version in the `pubspec.yaml` file.
2. Update the `CHANGELOG.md` file to reflect the changes made in the new version.
3. Create a new tag for the new version.
    - `git tag -a v1.0.2 -m "Release 1.0.2"`
4. Push the new tag to the repository.
    - `git push origin v1.0.2`