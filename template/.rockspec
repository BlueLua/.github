package = "__PACKAGE__"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/__REPO__.git",
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
    __MODULES__
  },
}
