package = "linux-only"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/linux-only.git",
}

description = {
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {},
}
