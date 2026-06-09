# BlueLua GitHub

Shared CI/CD workflows for [BlueLua] repositories.

## CI & CD Workflow (`ci.yml`)

This workflow conditionally runs checks on relevant file changes:

- Formatting linting with [StyLua]
- Static analysis with [Luacheck]
- Markdown linting with [markdownlint]
- Unit testing with [Busted] across OS and Lua versions
- [LuaRocks] publishing for releases and development builds

### Usage

See the [example configuration](examples/ci.yml) for usage details.

[BlueLua]: https://github.com/BlueLua
[StyLua]: https://github.com/JohnnyMorganz/StyLua
[Luacheck]: https://github.com/lunarmodules/luacheck
[markdownlint]: https://github.com/DavidAnson/markdownlint
[Busted]: https://lunarmodules.github.io/busted/
[LuaRocks]: https://luarocks.org
