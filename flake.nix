{
  description = "NixOS-first Neovim configuration manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.default = pkgs.writeShellApplication {
          name = "nvim-manager";
          runtimeInputs = with pkgs; [
            bash
            coreutils
            findutils
            gnugrep
            gnused
            gawk
            patch
            git
            neovim
            desktop-file-utils
            gcc
            gnumake
            tree-sitter
            wl-clipboard
            ripgrep
            lazygit
            gdu
            bottom
            python3
            nodejs
          ];
          text = builtins.readFile ./src/nvim-manager.sh;
        };
      }) // {
        homeManagerModules.default = import ./modules/home-manager.nix;
      };
}
