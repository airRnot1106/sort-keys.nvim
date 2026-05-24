{ self, pkgs }:
pkgs.runCommand "sort-keys-nvim-tests"
  {
    nativeBuildInputs = [ pkgs.neovim ];
    PLENARY_DIR = pkgs.vimPlugins.plenary-nvim;
    src = self;
  }
  ''
    export HOME=$(mktemp -d)
    cp -r $src ./src
    chmod -R +w ./src
    cd ./src
    nvim --headless --noplugin -u tests/minimal_init.lua \
      -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
    touch $out
  ''
