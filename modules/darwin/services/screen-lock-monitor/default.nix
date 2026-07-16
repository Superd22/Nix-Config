{ pkgs, ... }:

let
  screenLockMonitor = pkgs.stdenv.mkDerivation {
    pname = "screen-lock-monitor";
    version = "1.0.0";
    src = ./.;

    nativeBuildInputs = [ pkgs.swift ];

    buildPhase = ''
      swiftc -O -o screen-lock-monitor screen-lock-monitor.swift \
        -framework Cocoa -framework Foundation
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp screen-lock-monitor $out/bin/
    '';
  };
in
{
  environment.systemPackages = [ screenLockMonitor ];

  launchd.user.agents.screen-lock-monitor = {
    serviceConfig = {
      Label = "com.david.screen-lock-monitor";
      ProgramArguments = [ "${screenLockMonitor}/bin/screen-lock-monitor" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/screen-lock-monitor.log";
      StandardErrorPath = "/tmp/screen-lock-monitor.err";
    };
  };
}
