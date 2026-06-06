# BlueLua GitHub

GitHub profile, workflows, and shared files for [BlueLua].

## Shared GitHub Actions Workflows

We provide reusable workflows to standardize and simplify CI across all
[BlueLua] repositories.

### CI Workflow (`ci.yml`)

This workflow runs:

- [StyLua] for formatting
- [Luacheck] for static analysis
- [Prettier] for Markdown files
- [Busted] for unit testing

It runs checks conditionally on relevant file changes.

#### Usage

See [ci] for examples.

[BlueLua]: https://github.com/BlueLua
[StyLua]: https://github.com/JohnnyMorganz/StyLua
[Luacheck]: https://github.com/lunarmodules/luacheck
[Prettier]: https://prettier.io/
[Busted]: https://lunarmodules.github.io/busted/
[ci]: examples/ci.yml
