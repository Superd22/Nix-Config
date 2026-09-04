# Called by ../default.nix as a plain function, not evaluated as a module, so
# the account name and the betterdisplaycli path are passed in rather than read
# off `config`.
{ lib, pkgs, user, betterdisplaycli }:

let
  screenLockMonitor = pkgs.stdenv.mkDerivation {
    pname = "screen-lock-monitor";
    version = "1.0.0";
    src = ./.;

    nativeBuildInputs = [ pkgs.swift ];

    # The Swift source drives BetterDisplay, and used to reach it through
    # /usr/local/bin/betterdisplaycli — a path another module's activation
    # script happened to write. Baking the store path in at build time makes
    # that dependency an argument to this derivation instead of a convention
    # nothing enforced (#21). --replace-fail so a renamed placeholder is a build
    # error rather than a binary that silently points at nothing.
    buildPhase = ''
      substituteInPlace screen-lock-monitor.swift \
        --replace-fail "@betterdisplaycli@" "${lib.getExe betterdisplaycli}"

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
      # Reverse-DNS label keyed on the account that owns the agent, so a fork
      # does not end up running a job announced as david's.
      Label = "com.${user}.screen-lock-monitor";
      ProgramArguments = [ "${screenLockMonitor}/bin/screen-lock-monitor" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/screen-lock-monitor.log";
      StandardErrorPath = "/tmp/screen-lock-monitor.err";
    };
  };
}
