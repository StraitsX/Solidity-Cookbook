with import <nixpkgs> {};

pkgs.mkShell {
  name = "baas";
  buildInputs = [
    go
    gcc
    delve
    goconvey
    go-ethereum
  ];

  shellHook = ''
    go mod download
  '';
}
