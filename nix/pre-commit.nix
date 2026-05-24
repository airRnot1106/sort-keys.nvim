{ self, pkgs }:
let
  inherit (pkgs.lib) getExe;
in
{
  src = self;
  hooks = {
    gitleaks = rec {
      enable = true;
      package = pkgs.gitleaks;
      entry = "${getExe package} git --pre-commit --redact --staged --verbose";
      pass_filenames = false;
    };
    selene.enable = true;
    treefmt = {
      enable = true;
      package = self.formatter.${pkgs.stdenv.hostPlatform.system};
    };
  };
}
