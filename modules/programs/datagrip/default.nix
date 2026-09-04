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

    # "I want DataGrip" is one switch: the app and its connections. The cask
    # used to sit unconditionally in modules/homebrew.nix; this is the shape #9
    # gives the rest of them.
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
          done
        fi
      '';
    };
  };
}
