{
  description = "sort-keys.nvim — Neovim plugin for sorting keys";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems
          (system: f nixpkgs.legacyPackages.${system});

      mkSortKeysPlugin = pkgs: pkgs.vimUtils.buildVimPlugin {
        pname = "sort-keys.nvim";
        version = "0.0.0";
        src = ./.;
        meta = {
          description = "Sort keys in the current buffer or range";
          homepage = "https://github.com/airRnot/sort-keys.nvim";
          license = pkgs.lib.licenses.mit;
          platforms = pkgs.lib.platforms.all;
        };
      };

      mkWrappedNvim = pkgs:
        pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
          plugins = [
            { plugin = mkSortKeysPlugin pkgs; optional = false; }
          ];
          luaRcContent = ''
            vim.opt.swapfile = false
            require("sort-keys").setup({})
          '';
          wrapRc = true;
          withPython3 = false;
          withRuby = false;
          withNodeJs = false;
          viAlias = false;
          vimAlias = false;
        };

      mkDevLauncher = pkgs:
        let
          initLua = pkgs.writeText "sort-keys-dev-init.lua" ''
            -- Minimal init for sort-keys.nvim development.
            -- Loads the plugin from the current working directory so edits
            -- to lua/ and plugin/ are picked up without rebuilding.
            vim.opt.runtimepath:prepend(vim.fn.getcwd())
            vim.opt.swapfile = false
            vim.cmd("runtime plugin/sort-keys.lua")
          '';
        in
        pkgs.writeShellApplication {
          name = "sort-keys-dev-nvim";
          runtimeInputs = [ pkgs.neovim ];
          text = ''exec nvim -u ${initLua} "$@"'';
        };
    in
    {
      packages = forAllSystems (pkgs: {
        sort-keys-nvim = mkSortKeysPlugin pkgs;
        nvim = mkWrappedNvim pkgs;
        default = mkWrappedNvim pkgs;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${mkWrappedNvim pkgs}/bin/nvim";
          meta.description = "Neovim wrapped with sort-keys.nvim (packpath install)";
        };
        dev = {
          type = "app";
          program = "${mkDevLauncher pkgs}/bin/sort-keys-dev-nvim";
          meta.description = "Dev launcher: load sort-keys.nvim from cwd (live edits)";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            neovim
            stylua
            selene
            git
            gnumake
          ];

          shellHook = ''
            echo "sort-keys.nvim dev shell"
            echo "  nvim   : $(nvim --version | head -n1)"
            echo "  stylua : $(stylua --version)"
            echo "  selene : $(selene --version)"
            echo ""
            echo "Try: nix run .#dev   # dev launcher (live edits from cwd)"
            echo "     nix run         # wrapped nvim (packpath install)"
            echo "     make test       # run plenary specs"
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
