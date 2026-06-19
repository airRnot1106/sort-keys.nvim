{
  inputs = {
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pproenca-skills = {
      url = "github:pproenca/dot-skills";
      flake = false;
    };
  };

  outputs =
    {
      agent-skills,
      nixpkgs,
      pproenca-skills,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forEachSystem = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          agentLib = agent-skills.lib.agent-skills;
          sources = {
            pproenca-skills = {
              path = pproenca-skills;
              subdir = "skills";
            };
          };
          catalog = agentLib.discoverCatalog sources;
          selection = agentLib.selectSkills {
            inherit catalog sources;
            skills = {
              vhs = {
                from = "pproenca-skills";
                path = ".experimental/vhs";
              };
            };
          };
          bundle = agentLib.mkBundle { inherit pkgs selection; };
          localTargets = {
            claude = agentLib.defaultLocalTargets.claude // {
              enable = true;
            };
          };
        in
        {
          default = pkgs.mkShellNoCC {
            shellHook = agentLib.mkShellHook {
              inherit pkgs bundle;
              targets = localTargets;
            };
          };
        }
      );
    };
}
