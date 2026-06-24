{
  pkgs ? import <nixpkgs> { },
  buildGoModule ? pkgs.buildGoModule,
  version ? "unstable",
}:

buildGoModule {
  pname = "kcptun";
  inherit version;

  src = ./.;

  subPackages = [
    "client"
    "server"
  ];

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
    "-X main.VERSION=${version}"
  ];

  postInstall = ''
    mv "$out/bin/client" "$out/bin/kcptun-client"
    mv "$out/bin/server" "$out/bin/kcptun-server"
  '';
}
