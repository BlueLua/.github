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
}

build = {
  type = "builtin",
  modules = {
    ["pure-lua"] = "src/pure-lua/init.lua",
    ["pure-lua.util"] = "src/pure-lua/util.lua",
  },
}
