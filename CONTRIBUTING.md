# Contributing

First off, thanks for taking the time to contribute! ❤️

All contribution types are welcome: bug reports, feature ideas, docs updates,
tests, and code improvements. 🎉

## Table of Contents

- [I Have a Question](#i-have-a-question)
  - [I Want To Contribute](#i-want-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Improving The Documentation](#improving-the-documentation)
- [Styleguides](#styleguides)
  - [Commit Messages](#commit-messages)

## I Have a Question

Before asking a question:

- Read the repository's documentation.
- Check existing [issues](../../../issues).
- Check [discussions](../../../discussions).
- Search the internet for existing answers.

If you still need help, use
[GitHub Discussions](../../../discussions/new?category=q-a) or open a new
[question issue](../../../issues/new?template=question.yml) with your relevant
context.

### I Want To Contribute

Contributions of all sizes are welcome. Keep changes focused and small. By
contributing, you agree your contributions are provided under this repository's
[LICENSE](LICENSE).

Before opening a PR:

- For larger changes, start with an [issue](../../../issues) or
  [discussion](../../../discussions) first.
- Prefer one clear purpose per PR.
- Include related [`tests/`](tests/) updates when behavior changes.

### Reporting Bugs

Before submitting a bug report, read the repository's documentation, check
[discussions](../../../discussions) and existing [issues](../../../issues), and
search the internet for similar reports or fixes to avoid duplicates and
continue existing threads.

When reporting a bug, include:

- Steps to reproduce.
- Expected result and actual result.
- Lua version and platform details.
- Minimal example when possible.

### Suggesting Enhancements

For enhancements, read the repository's documentation, check
[discussions](../../../discussions) and existing [issues](../../../issues) to
avoid duplicate requests, then open an issue and include:

- The problem you want to solve.
- The proposed behavior.
- Why it helps most users.
- Any alternatives you considered.

### Your First Code Contribution

#### Testing

Tests live in [`tests/`](tests/). Add or update specs there when behavior
changes.

Run tests with [Busted]:

```sh
# All tests
busted

# One spec file while iterating
busted tests/<module>_spec.lua
```

#### Linting

Run lint checks before opening a PR:

- Run Lua lint with [LuaCheck]:

  ```sh
  luacheck .
  ```

- Run Markdown lint with [markdownlint-cli2]:

  ```sh
  # If markdownlint-cli2 is installed globally
  markdownlint-cli2 '*.md'

  # If you want to run it through npx
  npx --yes markdownlint-cli2 '*.md'
  ```

#### Formatting

Run formatters before opening a PR:

- Format `.md`, `.json`, `.yml`, `.ts`, and `.mts` files with [Prettier]:

  ```sh
  # If Prettier is installed globally
  prettier --write .

  # If you want to run it through npx
  npx --yes prettier --write .
  ```

- Format `.lua` files with [StyLua]:

  ```sh
  stylua .
  ```

## Improving The Documentation

- The documentation website code and guides live in the [bluelua.github.io]
  repository.
- For website updates, guides, or layout improvements, please open pull requests
  there.
- For inline API documentation changes, update the source annotations directly
  in the code or type definitions of the corresponding repository.

## Styleguides

### Commit Messages

This project follows [Conventional Commits] 1.0.0.

[Busted]: https://github.com/lunarmodules/busted
[LuaCheck]: https://github.com/mpeterv/luacheck
[markdownlint-cli2]: https://github.com/DavidAnson/markdownlint-cli2
[Prettier]: https://prettier.io/
[StyLua]: https://github.com/JohnnyMorganz/StyLua
[bluelua.github.io]: https://github.com/BlueLua/bluelua.github.io
[Conventional Commits]: https://www.conventionalcommits.org/en/v1.0.0/
