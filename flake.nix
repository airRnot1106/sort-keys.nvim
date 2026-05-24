{
  description = "sort-keys.nvim — Neovim plugin for sorting keys";

  inputs = {
    agent-skills = {
      url = "path:./nix/agent-skills";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      agent-skills,
      git-hooks,
      nixpkgs,
      treefmt-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      mkSortKeysPlugin =
        pkgs:
        pkgs.vimUtils.buildVimPlugin {
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

      mkSortKeysParsers =
        pkgs:
        pkgs.vimPlugins.nvim-treesitter.withPlugins (
          parsers: with parsers; [
            javascript
            json
            lua
            nix
            toml
            typescript
            yaml
          ]
        );

      mkWrappedNvim =
        pkgs:
        pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
          plugins = [
            {
              plugin = mkSortKeysPlugin pkgs;
              optional = false;
            }
            {
              plugin = mkSortKeysParsers pkgs;
              optional = false;
            }
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

      mkDevLauncher =
        pkgs:
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

      mkVhsNvim =
        pkgs:
        pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
          plugins = [
            {
              plugin = mkSortKeysParsers pkgs;
              optional = false;
            }
            {
              plugin = pkgs.vimPlugins.lualine-nvim;
              optional = false;
            }
          ];
          wrapRc = false;
          withPython3 = false;
          withRuby = false;
          withNodeJs = false;
          viAlias = false;
          vimAlias = false;
        };

      mkVhsApp =
        pkgs:
        pkgs.writeShellApplication {
          name = "sort-keys-vhs";
          runtimeInputs = with pkgs; [
            vhs
            (mkVhsNvim pkgs)
            git
            ttyd
            ffmpeg
          ];
          text = ''
            cd "$(git rev-parse --show-toplevel)"
            exec vhs vhs/demo.tape
          '';
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
        vhs = {
          type = "app";
          program = "${mkVhsApp pkgs}/bin/sort-keys-vhs";
          meta.description = "Regenerate vhs/demo.gif from vhs/demo.tape";
        };
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShellNoCC {
            inputsFrom = [ agent-skills.devShells.${pkgs.stdenv.hostPlatform.system}.default ];
            inherit shellHook;
            packages =
              (with pkgs; [
                git
                neovim
              ])
              ++ enabledPackages;
          };
        }
      );

      formatter = forAllSystems (
        pkgs:
        let
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix;
        in
        treefmtEval.config.build.wrapper
      );

      checks = forAllSystems (pkgs: {
        pre-commit = git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run (
          import ./nix/pre-commit.nix {
            inherit self pkgs;
          }
        );
        test = import ./nix/test.nix {
          inherit self pkgs;
        };
      });
    };
}
