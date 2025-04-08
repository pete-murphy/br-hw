{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    # elm-format is broken on recent nixpkgs: https://github.com/NixOS/nixpkgs/issues/370084
    elm-nixpkgs.url = "github:NixOS/nixpkgs/7e2fb8e0eb807e139d42b05bf8e28da122396bed";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = {
    self,
    nixpkgs,
    elm-nixpkgs,
    pre-commit-hooks,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
          elm-pkgs = import elm-nixpkgs {inherit system;};
          inherit system;
        });
  in {
    checks = forEachSupportedSystem ({
      pkgs,
      system,
      ...
    }: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true; # Nix formatter
          elm-format.enable = true;
          prettier = {
            enable = true;
            exclude_types = ["json"];
            settings.configPath = "./package.json";
          };
          rustywind = {
            enable = true;
            entry = "just sort";
            pass_filenames = false;
          };
        };
      };
    });

    devShells = forEachSupportedSystem ({
      pkgs,
      elm-pkgs,
      system,
    }: {
      default = pkgs.mkShell {
        buildInputs =
          self.checks.${system}.pre-commit-check.enabledPackages
          ++ [
            # Elm
            elm-pkgs.elmPackages.elm
            elm-pkgs.elmPackages.elm-format
            elm-pkgs.elmPackages.elm-test-rs
            elm-pkgs.elmPackages.elm-json
            elm-pkgs.elmPackages.elm-language-server
            elm-pkgs.elm2nix

            # JS
            pkgs.nodejs_22
            pkgs.typescript

            # Nix
            pkgs.alejandra

            # Scripts
            pkgs.just
            pkgs.bun

            # Tailwind
            pkgs.rustywind
          ];
        shellHook = ''
          ${self.checks.${system}.pre-commit-check.shellHook}
          npm install
          export PATH="$PWD/node_modules/.bin/:$PATH"
        '';
      };
    });
  };
}
