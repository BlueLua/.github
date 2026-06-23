package = "c-extension"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/c-extension.git",
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
    ["c-extension"] = "src/c-extension/init.lua",
    ["c-extension._core"] = {
      sources = {
        "src/c-extension/device.c",
        "src/c-extension/util.c",
      },
    },
    ["c-extension.types/c-extension"] = "types/c-extension.d.lua",
  },
}
