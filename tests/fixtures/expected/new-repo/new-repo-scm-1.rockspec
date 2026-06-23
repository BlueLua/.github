package = "new-repo"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/new-repo.git",
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
