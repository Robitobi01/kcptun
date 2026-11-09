{ ... }:

{
  # When using a pinned source, import (source + "/nix/module.nix") instead.
  imports = [ ./module.nix ];

  services.kcptun = {
    enable = true;
    servers.example = {
      listen = ":29900";
      target = "127.0.0.1:25565";
      keyFile = "/etc/kcptun/example.key";
      # settings = { mode = "fast3"; nocomp = true; };
    };
  };

  networking.firewall.allowedUDPPorts = [ 29900 ];
}
