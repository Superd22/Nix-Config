# DataGrip: the cask, plus datasource definitions applied to the IDE (#7).
#
# NOTE ON SCOPE: this is a *nix-darwin* module, not a home-manager one, even
# though it lives next to the home-manager modules in modules/programs. It has
# to be: it declares the Homebrew cask (system) and the datasource file (home),
# and those two belong to the same "I want DataGrip" switch. It is imported by
# modules/home-manager.nix and deliberately *not* by modules/programs/default.nix,
# which is the home-manager import list. Same arrangement as modules/desktop/raycast.
#
#
# WHY A GLOBAL FILE AND NOT A PROJECT ONE
#
# DataGrip stores datasources at two levels. Project level is
# `<project>/.idea/dataSources.xml`, which is what the IDE writes by default and
# what used to be committed under modules/config/datagrip — the wrong scope for
# "the same connections on every machine", since it is tied to one checkout of
# one repo. Global level is `<ide config dir>/options/dataSources.xml`, which
# every project sees. That is the one this module writes, so the connections are
# simply *there* in whatever project you open, with nothing to import.
#
# The two files are not the same format, and the difference is not documented,
# so it was read out of the IDE itself
# (com.intellij.database.dataSource.DataSourceStorageShared):
#
#   project: .idea/dataSources.xml     root <project>      component "DataSourceManagerImpl"
#   global:  options/dataSources.xml   root <application>  component "dataSourceStorage"
#
# The `<data-source>` elements inside are identical between the two; the same
# serializer reads both.
#
#
# WHY AN ACTIVATION SCRIPT AND NOT home.file
#
# Two reasons. The IDE config directory is version-stamped —
# ~/Library/Application Support/JetBrains/DataGrip2024.3, DataGrip2026.2, … — so
# the target path moves on every IDE upgrade and cannot be written down here.
# The activation script finds them all by glob instead, which means an upgrade
# needs no change to this file, and asks the installed app for the name of the
# one that does not exist yet (`dataDirectoryName` in its product-info.json).
# That second half is what makes this work on a machine where DataGrip has never
# run: the file is in place before the first launch, so the first launch has the
# connections. Homebrew installs the cask earlier in the same activation.
#
# And `home.file` symlinks into the nix store, which is read-only. DataGrip
# rewrites this file whenever anything about a datasource changes in the UI, so
# a read-only target is a file the IDE cannot save. The generated file is copied
# in writable instead: the IDE stays able to edit it, this config wins again on
# the next `build-switch`, and drift in between is the accepted trade.
#
# Whatever was there before the first run is kept once as
# `dataSources.xml.before-nix`.
{ config, lib, pkgs, ... }:

let
  cfg = config.mine.programs.datagrip;
  user = config.mine.user.name;

  # `driver` is DataGrip's own driver id (what it writes as <driver-ref>), and
  # the JDBC class follows from it. Listing the mapping here keeps a datasource
  # declaration down to the driver name; `jdbcDriver` overrides it for a driver
  # that is not in this table.
  jdbcDrivers = {
    postgresql = "org.postgresql.Driver";
    mysql = "com.mysql.cj.jdbc.Driver";
    mariadb = "org.mariadb.jdbc.Driver";
    sqlite = "org.sqlite.JDBC";
    mssql = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
    clickhouse = "com.clickhouse.jdbc.ClickHouseDriver";
    redshift = "com.amazon.redshift.jdbc.Driver";
    snowflake = "net.snowflake.client.jdbc.SnowflakeDriver";
    oracle = "oracle.jdbc.OracleDriver";
    cassandra = "com.dbschema.CassandraJdbcDriver";
    mongo = "com.dbschema.MongoJdbcDriver";
  };

  # DataGrip keys everything it discovers for itself — introspection caches,
  # the colour you assigned a connection, the server version it detected — by
  # datasource uuid, in files this module does not manage. So the uuid has to be
  # stable across machines and across rewrites of this file, which rules out
  # generating a fresh one. Deriving it from the name gives the same datasource
  # the same uuid everywhere, with no uuid to paste into the declaration.
  mkUuid = name:
    let
      h = builtins.hashString "md5" "nix-datagrip:${name}";
      part = start: len: builtins.substring start len h;
    in
    "${part 0 8}-${part 8 4}-${part 12 4}-${part 16 4}-${part 20 12}";

  # <jdbc-additional-properties> is where the AWS toolkit looks for the region
  # and the credential profile to mint an RDS IAM token with. The `profile:`
  # prefix is the toolkit's own namespacing of credential ids, so the option
  # takes the bare profile name.
  awsProperties = ds:
    (lib.optionalAttrs (ds.awsRegion != null) { "AWS.RegionId" = ds.awsRegion; })
    // (lib.optionalAttrs (ds.awsProfile != null) { "AWS.CredentialId" = "profile:${ds.awsProfile}"; })
    // ds.properties;

  element = indent: name: value: "${indent}<${name}>${lib.escapeXML value}</${name}>";

  dataSourceXml = ds:
    let
      props = awsProperties ds;
      propXml = lib.mapAttrsToList
        (n: v: "        <property name=\"${lib.escapeXML n}\" value=\"${lib.escapeXML v}\" />")
        props;
    in
    lib.concatStringsSep "\n" (
      [ "    <data-source source=\"LOCAL\" name=\"${lib.escapeXML ds.name}\" uuid=\"${ds.uuid}\">" ]
      ++ [
        (element "      " "driver-ref" ds.driver)
        "      <synchronize>true</synchronize>"
        (element "      " "jdbc-driver" ds.jdbcDriver)
        (element "      " "jdbc-url" ds.url)
      ]
      ++ lib.optional (ds.userName != null) (element "      " "user-name" ds.userName)
      ++ lib.optional (ds.authProvider != null) (element "      " "auth-provider" ds.authProvider)
      ++ lib.optional (ds.secretStorage != null) (element "      " "secret-storage" ds.secretStorage)
      ++ lib.optionals (props != { }) (
        [ "      <jdbc-additional-properties>" ] ++ propXml ++ [ "      </jdbc-additional-properties>" ]
      )
      ++ [ "    </data-source>" ]
    );

  datasources = lib.attrValues cfg.datasources;

  # Assembled by hand rather than with an XML library, because there is no XML
  # writer in lib and the document is four elements deep. Everything that comes
  # from a declaration goes through `lib.escapeXML`.
  dataSourcesXml = lib.concatStringsSep "\n" (
    [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      "<!-- Generated by modules/programs/datagrip. Edits here are overwritten on"
      "     the next `nix run .#build-switch`; change the nix config instead. -->"
      "<application>"
      "  <component name=\"dataSourceStorage\">"
    ]
    ++ map dataSourceXml datasources
    ++ [
      "  </component>"
      "</application>"
      ""
    ]
  );

  dataSourcesFile = builtins.toFile "datagrip-dataSources.xml" dataSourcesXml;

  # The datasources above are application-level, so every project sees them —
  # but the Database tool window is project-scoped, and DataGrip with no project
  # open is a welcome screen with nowhere to show them. A machine built from
  # this repo therefore came up looking like the config had not applied at all,
  # when in fact the file was in place and simply had no window to appear in.
  #
  # So the project is declared too. `RecentProjectsManager` is the component
  # that decides what a launch opens (read out of the IDE the same way the
  # datasource format was: `com.intellij.ide.RecentProjectsManagerBase`, storage
  # `recentProjects.xml`), and `opened` on a `RecentProjectMetaInfo` is what
  # `willReopenProjectOnStart` looks for. Seeding one entry makes the first
  # launch land in a project with the connections already in it.
  #
  # `$USER_HOME$` is the IDE's own path macro, not a shell variable — it is
  # written literally, and DataGrip expands it.
  # `aws.rds.iam` is not DataGrip's own auth provider — nothing in the app
  # bundle defines it (the bundled `database-cloudExplorer-aws` is the cloud
  # browser, not the credential half). It comes from the AWS Toolkit plugin, so
  # a datasource declared with `awsProfile` is listed but cannot connect until
  # that plugin is installed. Declaring the datasource and then installing the
  # plugin by hand is exactly the manual step this module exists to remove, so
  # the plugin follows from the datasources that need it.
  needsAwsToolkit = lib.any (ds: ds.authProvider == "aws.rds.iam") datasources;

  # Plugins are unpacked into the IDE config directory, which is the same
  # per-version directory the datasources go into and is found the same way.
  pluginDirs = lib.mapAttrs
    (name: plugin: pkgs.fetchzip {
      inherit (plugin) url hash;
      name = "datagrip-plugin-${name}";
    })
    cfg.plugins;

  # Installed once per config directory and then left alone: the IDE updates
  # its own plugins, and re-copying a pinned version over a newer one it fetched
  # for itself would be this module picking a fight it does not need to win.
  # Indented to sit where it is interpolated: nix strips the common leading
  # whitespace off an indented string, so it has to be put back by hand.
  indent = n: text:
    let pad = lib.concatStrings (lib.genList (_: " ") n);
    in pad + lib.replaceStrings [ "\n" ] [ "\n${pad}" ] text;

  pluginInstall = indent 12 (lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: drv: ''
      dest="''${dir}plugins/${name}"
      if [ ! -e "$dest" ]; then
        $DRY_RUN_CMD mkdir -p "$dest"
        $DRY_RUN_CMD cp -R ${drv}/. "$dest/"
        # The store is read-only and the IDE expects to be able to update
        # what it finds here.
        $DRY_RUN_CMD chmod -R u+w "$dest"
      fi'')
    pluginDirs));

  projectName = baseNameOf cfg.defaultProject;
  projectParent = dirOf cfg.defaultProject;

  recentProjectsFile = builtins.toFile "datagrip-recentProjects.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Seeded by modules/programs/datagrip on a machine where DataGrip had no
         project of its own yet. DataGrip owns this file from here on. -->
    <application>
      <component name="RecentProjectsManager">
        <option name="additionalInfo">
          <map>
            <entry key="$USER_HOME$/${cfg.defaultProject}">
              <value>
                <RecentProjectMetaInfo frameTitle="${lib.escapeXML projectName}" opened="true">
                  <option name="displayName" value="${lib.escapeXML projectName}" />
                </RecentProjectMetaInfo>
              </value>
            </entry>
          </map>
        </option>
        <option name="lastProjectLocation" value="$USER_HOME$/${projectParent}" />
      </component>
    </application>
  '';

  datasourceModule = { name, config, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = ''
          Name shown in the Database tool window. Defaults to the attribute
          name; set it when the display name is awkward as an attribute name.
        '';
      };

      driver = lib.mkOption {
        type = lib.types.str;
        example = "postgresql";
        description = ''
          DataGrip's driver id, written as `<driver-ref>`. Known ids:
          ${lib.concatStringsSep ", " (lib.attrNames jdbcDrivers)}. Any other id
          works too, but then `jdbcDriver` has to be set as well.
        '';
      };

      jdbcDriver = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = jdbcDrivers.${config.driver} or null;
        defaultText = lib.literalMD "the JDBC class that goes with `driver`";
        description = "JDBC driver class. Derived from `driver` for known drivers.";
      };

      url = lib.mkOption {
        type = lib.types.str;
        example = "jdbc:postgresql://db.example.com:5432/postgres";
        description = "JDBC connection URL.";
      };

      userName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Database user. Not a secret — with `aws.rds.iam` the password is a
          short-lived token the AWS toolkit mints per connection.
        '';
      };

      awsProfile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "prod:sudo";
        description = ''
          AWS profile (as named in ~/.aws/config, without the `profile:` prefix
          DataGrip adds) used to authenticate. Setting this switches the
          datasource to RDS IAM auth unless `authProvider` says otherwise.
        '';
      };

      awsRegion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "eu-west-1";
        description = "AWS region the database lives in.";
      };

      authProvider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if config.awsProfile != null then "aws.rds.iam" else null;
        defaultText = lib.literalMD "`\"aws.rds.iam\"` when `awsProfile` is set, otherwise null";
        description = ''
          DataGrip auth provider id. `aws.rds.iam` means "get a token from the
          AWS toolkit", which is why none of this needs a secret in the store.
        '';
      };

      secretStorage = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if config.authProvider != null then "master_key" else null;
        defaultText = lib.literalMD "`\"master_key\"` when an auth provider is set";
        description = ''
          Where DataGrip keeps whatever credential this datasource does have.
          `master_key` is the IDE's own keychain-backed store — nothing lands
          on disk in the clear, and nothing lands in this repo.
        '';
      };

      uuid = lib.mkOption {
        type = lib.types.str;
        default = mkUuid config.name;
        defaultText = lib.literalMD "derived from `name`, so it is the same on every machine";
        description = ''
          Datasource uuid. Set it to keep the local state (colours,
          introspection cache) of a datasource that already exists in the IDE
          under a uuid DataGrip generated.
        '';
      };

      properties = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = { "AWS.SsoUrl" = "https://example.awsapps.com/start"; };
        description = ''
          Extra `<jdbc-additional-properties>` entries, merged with the ones
          `awsRegion` and `awsProfile` generate.
        '';
      };
    };
  };
in
{
  # `mine.programs.datagrip.enable` itself is declared in modules/options.nix,
  # with the rest of the opt-in flags. Only the schema below lives here.
  options.mine.programs.datagrip.defaultProject = lib.mkOption {
    type = lib.types.str;
    default = "DataGripProjects/Databases";
    example = "src/db";
    description = ''
      Project DataGrip opens on launch, as a path relative to the home
      directory. It is created empty if it does not exist.

      DataGrip only draws the Database tool window inside a project, so without
      one the datasources below are loaded but have nowhere to appear, and a
      freshly built machine looks like the config did not apply. Seeding a
      project means the first launch lands somewhere they are visible.

      This is a *seed*: it is written only while DataGrip has no project of its
      own on the machine, and the IDE owns `recentProjects.xml` from then on, so
      it never fights whatever you go on to open.
    '';
  };

  options.mine.programs.datagrip.plugins = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        url = lib.mkOption {
          type = lib.types.str;
          description = "Marketplace download URL for the plugin archive.";
        };
        hash = lib.mkOption {
          type = lib.types.str;
          description = "SRI hash of that archive.";
        };
      };
    });
    default = { };
    description = ''
      Plugins to unpack into DataGrip's config directory, keyed by the
      directory name to give them.

      The URL is a pinned marketplace artifact, which means it is pinned to an
      IDE build too: `https://plugins.jetbrains.com/pluginManager?action=download&id=<id>&build=<buildNumber>`
      redirects to the version compatible with the build in
      `/Applications/DataGrip.app/Contents/Resources/product-info.json`, and
      that redirect target is what goes here. After a major IDE upgrade the
      pinned build may no longer be compatible and DataGrip will disable the
      plugin — re-resolve the URL and update the hash.

      Each is installed only if its directory is absent, so the IDE's own
      plugin updates are left alone.
    '';
  };

  options.mine.programs.datagrip.datasources = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule datasourceModule);
    default = { };
    example = lib.literalExpression ''
      {
        "[PROD] PG" = {
          driver = "postgresql";
          url = "jdbc:postgresql://db.example.com:5432/postgres";
          userName = "backend_dev";
          awsProfile = "prod:sudo";
          awsRegion = "eu-west-1";
        };
      }
    '';
    description = ''
      Database connections to define in DataGrip, as global datasources: they
      show up in every project you open, so there is nothing to import and no
      per-checkout `.idea` to keep in sync.

      Passwords are out of scope on purpose. Everything here is an endpoint, a
      user name and an AWS profile — none of which is a secret — and the actual
      credential is either an RDS IAM token minted per connection or something
      the IDE keeps in its own keychain-backed store.
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList
      (attr: ds: {
        assertion = ds.jdbcDriver != null;
        message = ''
          mine.programs.datagrip.datasources.${attr} uses driver "${ds.driver}",
          which this module has no JDBC class for. Set `jdbcDriver` on it, or
          add the driver to jdbcDrivers in modules/programs/datagrip.
        '';
      })
      cfg.datasources;

    # AWS Toolkit, whenever something here actually authenticates with it.
    # `mkDefault` so a host can pin a different version, and a plain merge so a
    # host can add plugins of its own alongside it.
    #
    # YAML comes with it. Not as a nicety — the toolkit's `plugin-intellij.xml`
    # carries a hard `<depends>org.jetbrains.plugins.yaml</depends>`, and
    # DataGrip does not bundle YAML the way IDEA does, so without it the
    # toolkit refuses to load and the RDS datasources are back to having no
    # `aws.rds.iam` provider. Marketplace resolves plugin dependencies for you;
    # a pinned artifact URL does not, so a transitive dependency has to be
    # pinned as its own entry here.
    #
    # Both are resolved for DataGrip build DB-261.26222.86 (2026.1.4).
    mine.programs.datagrip.plugins = lib.mkIf needsAwsToolkit {
      aws-toolkit = lib.mkDefault {
        url = "https://downloads.marketplace.jetbrains.com/files/11349/1120580/aws-toolkit-jetbrains-standalone-4.7.261.zip";
        hash = "sha256-4OHKxrLaSxRjn4U/sVasGImpWFIdD62sbQ2hTjAODV0=";
      };

      yaml = lib.mkDefault {
        url = "https://downloads.marketplace.jetbrains.com/files/13126/1086328/yaml-261.26222.22.zip";
        hash = "sha256-jQP/ksyFlAiRc4r/nA/fhWy29zvOe47B+0tHoW3RepA=";
      };
    };

    # "I want DataGrip" is one switch: the app and its connections. The cask
    # used to sit unconditionally in modules/homebrew.nix; #9 gave the rest of
    # them the same shape — either a module owns a cask, or a host lists it.
    homebrew.casks = [ "datagrip" ];

    home-manager.users.${user} = { lib, ... }: {
      home.activation.datagripDataSources = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        jetbrains="$HOME/Library/Application Support/JetBrains"
        datagripDirs=()

        # One config directory per IDE version that has ever run on this
        # machine. Writing to all of them means an upgrade needs no change here,
        # and a version you still occasionally open keeps working.
        for dir in "$jetbrains"/DataGrip*/; do
          [ -d "$dir" ] && datagripDirs+=("$dir")
        done

        # On a fresh machine none of those exist yet — the IDE creates its
        # config directory on first run. But the *app* knows what that directory
        # will be called: product-info.json carries `dataDirectoryName`. Reading
        # it puts the datasources in place before DataGrip has ever been opened,
        # so the first launch already has them. nix-darwin runs `brew bundle`
        # earlier in this same activation than home-manager, so even the very
        # first build-switch on a new machine finds the app here.
        for app in /Applications/DataGrip.app "$HOME/Applications/DataGrip.app"; do
          info="$app/Contents/Resources/product-info.json"
          [ -f "$info" ] || continue
          dataDir=$(${pkgs.jq}/bin/jq -r '.dataDirectoryName // empty' "$info")
          [ -n "$dataDir" ] || continue
          dir="$jetbrains/$dataDir/"
          # Any machine that has run DataGrip already has this from the glob.
          [ -d "$dir" ] || datagripDirs+=("$dir")
        done

        if [ ''${#datagripDirs[@]} -eq 0 ]; then
          # No config directory, and no app to ask what it will be called: the
          # cask is not installed yet, which is the one case this cannot fix.
          echo "datagrip: DataGrip is not installed yet, so there is no config" \
               "directory to write to. Re-run build-switch once the cask is in." >&2
        else
          if pgrep -qx datagrip 2>/dev/null; then
            echo "datagrip: DataGrip is running — it rewrites its datasource file on exit," \
                 "which will undo this. Quit it and re-run build-switch." >&2
          fi

          for dir in "''${datagripDirs[@]}"; do
            target="''${dir}options/dataSources.xml"
            $DRY_RUN_CMD mkdir -p "''${dir}options"
            # Keep one copy of whatever was there before this module first ran,
            # since global datasources made by hand live in the same file.
            if [ -e "$target" ] && [ ! -e "$target.before-nix" ]; then
              $DRY_RUN_CMD cp "$target" "$target.before-nix"
            fi
            # `install` rather than `cp`: the source is a read-only store path,
            # and DataGrip has to be able to write this file.
            $DRY_RUN_CMD install -m 0644 ${dataSourcesFile} "$target"

            # Somewhere for them to be shown. Only while DataGrip has no
            # project of its own: an entry-less file counts as none, which is
            # the state a machine is in after the IDE has been launched once
            # and closed at the welcome screen without opening anything.
            recent="''${dir}options/recentProjects.xml"
            if [ ! -e "$recent" ] || ! ${pkgs.gnugrep}/bin/grep -q "<entry key=" "$recent"; then
              $DRY_RUN_CMD mkdir -p "$HOME/${cfg.defaultProject}/.idea"
              $DRY_RUN_CMD install -m 0644 ${recentProjectsFile} "$recent"
            fi

${pluginInstall}
          done
        fi
      '';
    };
  };
}
