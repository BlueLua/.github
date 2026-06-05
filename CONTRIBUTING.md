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

- Read the official [documentation].
- Check existing issues.
- Check discussions.
- Search the internet for existing answers.

If you still need help, open a discussion or a question issue with your relevant
context.

### I Want To Contribute

Contributions of all sizes are welcome. Keep changes focused and small. All
contributions are licensed under the [LICENSE].

Before opening a PR:

- For larger changes, start with an issue or discussion first.
- Prefer one clear purpose per PR.
- Include related `tests/` updates when behavior changes.

### Reporting Bugs

Before submitting a bug report, read the official [documentation], check
discussions and existing issues, and search the internet for similar reports or
fixes to avoid duplicates and continue existing threads.

When reporting a bug, include:

- Steps to reproduce.
- Expected result and actual result.
- Lua version and platform details.
- Minimal example when possible.

### Suggesting Enhancements

For enhancements, read the official [documentation], check discussions and
existing issues to avoid duplicate requests, then open an issue and include:

- The problem you want to solve.
- The proposed behavior.
- Why it helps most users.
- Any alternatives you considered.

### Your First Code Contribution

#### Testing

Tests live in `tests/`. Add or update specs there when behavior changes.

Run tests with [Busted]:

```sh
# All tests
busted

# One spec file while iterating
busted tests/<module>_spec.lua
```

#### Linting

Run lint checks before opening a PR:

- **Lua** ([LuaCheck]):

  ```sh
  luacheck .
  ```

- **Markdown** ([markdownlint-cli2]):

  ```sh
  markdownlint-cli2 "*.md"
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

[bluelua.github.io]: https://github.com/BlueLua/bluelua.github.io
[Busted]: https://github.com/lunarmodules/busted
[Conventional Commits]: https://www.conventionalcommits.org/en/v1.0.0/
[documentation]: https://bluelua.github.io
[LICENSE]: LICENSE
[LuaCheck]: https://github.com/mpeterv/luacheck
[markdownlint-cli2]: https://github.com/DavidAnson/markdownlint-cli2
