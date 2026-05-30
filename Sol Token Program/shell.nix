# Import the nix package collection
with import <nixpkgs> {};

# Define the versions of packages we want to use
let
  # Use NodeJS version 18
  solanacli = pkgs.solana-cli;
  rust = pkgs.rustc;
  cargo = pkgs.cargo;
in

# Use pkgs.mkShell to create a shell environment for development
pkgs.mkShell {
  # Name of the environment
  name = "my-environment";

  # Packages to include in the environment
  buildInputs = [ pkg-config solanacli rustup];

  # Shell hook to run when the shell starts
  shellHook = ''
    cargo install spl-token-cli

  '';

}

