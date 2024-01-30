# Import the nix package collection
with import <nixpkgs> {};

# Define the versions of packages we want to use
let
  # Use NodeJS version 18
  nodejs = pkgs.nodejs-18_x;
  
in

# Use pkgs.mkShell to create a shell environment for development
pkgs.mkShell {
  # Name of the environment
  name = "my-environment";

  # Packages to include in the environment
  buildInputs = [ ngrok ];

  # Shell hook to run when the shell starts
  shellHook = ''

    mkdir -p ./bin

    # ./bin/ is installed using the avalanche cli install script
    curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s -- -b ./bin

    # set "avalanche bin" to path
    export PATH=./bin:$PATH

    # list network
    avalanche network status

    # Some web applications give an error if an other host header is present. This can be solved with the following command
    # ngrok http [port] --host-header="localhost:[port]"
    # hence to expose avax node ngrok http 127.0.0.1:9650 --host-header=127.0.0.1:9650
    
  '';

}
