{
  lib,
  buildVimPlugin,
}:
buildVimPlugin {
  pname = "sort-keys.nvim";
  version = "0.0.0";

  src = ./.;

  meta = {
    description = "Vim-like key sorting by treesitter";
    homepage = "https://github.com/airRnot1106/sort-keys.nvim";
    license = lib.licenses.mit;
  };
}
