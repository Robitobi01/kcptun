{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.services.kcptun;
  format = pkgs.formats.json { };
in {
  options.services.kcptun = {
    enable = mkEnableOption "kcptun server instances";
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../default.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../default.nix { }";
      description = "Package providing kcptun-server.";
    };
    servers = mkOption {
      default = { };
      description = "Named server instances, each creating kcptun-server-NAME.service.";
      type = types.attrsOf (types.submodule {
        options = {
          listen = mkOption {
            type = types.str;
            default = ":29900";
            description = "UDP listen address or port range.";
          };
          target = mkOption {
            type = types.str;
            description = "Destination TCP address or Unix socket path.";
          };
          keyFile = mkOption {
            type = types.str;
            description = "Absolute runtime path to a pre-shared key, not a Nix path literal. Keep it outside the Nix store, owned by root with mode 0600. A trailing newline is ignored.";
          };
          settings = mkOption {
            type = types.attrsOf format.type;
            default = { };
            example = { mode = "fast3"; nocomp = true; };
            description = "Additional non-secret JSON settings. listen and target use the dedicated options; key must use keyFile. Firewall rules remain host-managed. Raw TCP emulation is not supported by this unprivileged service.";
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    assertions = lib.mapAttrsToList (name: instance: {
      assertion = builtins.match "[A-Za-z0-9_-]+" name != null
        && lib.hasPrefix "/" instance.keyFile
        && !(lib.hasPrefix "/nix/store/" instance.keyFile)
        && !(instance.settings ? key)
        && !(instance.settings.tcp or false);
      message = "kcptun server ${name}: use a simple instance name, an absolute keyFile outside the Nix store, and non-secret settings without key or tcp=true.";
    }) cfg.servers;

    systemd.services = lib.mapAttrs' (name: instance:
      let
        settingsFile = format.generate "kcptun-server-${name}.json"
          (instance.settings // { inherit (instance) listen target; });
        start = pkgs.writeShellScript "kcptun-server-${name}" ''
          export KCPTUN_KEY="$(<"$CREDENTIALS_DIRECTORY/key")"
          if [ -z "$KCPTUN_KEY" ]; then
            echo "kcptun: keyFile must not be empty" >&2
            exit 1
          fi
          exec ${cfg.package}/bin/kcptun-server -c ${settingsFile}
        '';
      in lib.nameValuePair "kcptun-server-${name}" {
        description = "kcptun server (${name})";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = start;
          LoadCredential = [ "key:${instance.keyFile}" ];
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "3s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          UMask = "0077";
        };
      }) cfg.servers;
  };
}
