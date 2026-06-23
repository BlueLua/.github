package = "full-os"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/full-os.git",
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
