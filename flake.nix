{
  description = "different data structure in zig";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils}:
    utils.lib.eachDefaultSystem (system: 
      let
        inherit (nixpkgs) lib;
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells = {
          default = self.devShells."${system}".impure;
          impure = pkgs.mkShell {
            packages = with pkgs; [
              zig
            ];
          };
        };
      }
    );
}
