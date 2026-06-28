package = "pure-lua-package"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/pure-lua.git",
}

description = {
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "luafilesystem >= 1.8.0",
  "penlight",
}

build = {
  type = "builtin",
  modules = {
    ["pure-lua"] = "src/pure-lua/init.lua",
    ["pure-lua.util"] = "src/pure-lua/util.lua",
  },
  install = {
    bin = {
      ["pure-lua"] = "bin/pure-lua",
    },
  },
}
