{
  lib,
  buildVimPlugin,
}:
buildVimPlugin {
  pname = "sort-keys.nvim";
  version = "0.1.0";

  src = ./.;

  meta = {
    description = "Sort object/table keys using tree-sitter, similar to the built-in sort command";
    homepage = "https://github.com/airRnot1106/sort-keys.nvim";
    license = lib.licenses.mit;
  };
}
