{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nvim-manager;
  nvimManagerPkg = pkgs.writeShellApplication {
    name = "nvim-manager";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      patch
      git
      neovim
      desktop-file-utils
    ];
    text = builtins.readFile ../src/nvim-manager.sh;
  };

  mkLauncher = type: configName: {
    name = "${if type == "neovide" then "Neovide" else "Neovim"} (${configName})";
    comment = "Neovim GUI using ${configName} configuration";
    exec = "env NVIM_APPNAME=${configName} ${if type == "neovide" then "neovide" else "nvim-qt"}";
    icon = cfg.gui.icon;
    terminal = false;
    categories = [ "Development" "TextEditor" ];
    mimeType = [
      "text/plain"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-moc"
      "text/x-pascal"
      "text/x-tcl"
      "text/x-tex"
      "application/x-shellscript"
      "text/x-c"
      "text/x-c++"
    ];
    keywords = [ "Text" "editor" configName ];
  };

  launcherEntries =
    lib.listToAttrs (map
      (configName: {
        name = "${if cfg.gui.type == "neovide" then "neovide" else "nvim-qt"}-${configName}";
        value = mkLauncher cfg.gui.type configName;
      })
      cfg.gui.configs);

in {
  options.programs.nvim-manager = {
    enable = lib.mkEnableOption "nvim-manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = nvimManagerPkg;
      defaultText = "nvim-manager from this module";
      description = "The nvim-manager package to install.";
    };

    patchesPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ./patches;
      description = "Path to patch files that should be linked into ~/.config/nvim-manager/patches.";
    };

    gui = {
      enable = lib.mkEnableOption "desktop launchers for Neovim configs";

      type = lib.mkOption {
        type = lib.types.enum [ "neovide" "nvim-qt" ];
        default = "neovide";
        description = "Which GUI to use for desktop launchers.";
      };

      configs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of NVIM_APPNAME values to create launchers for.";
      };

      icon = lib.mkOption {
        type = lib.types.str;
        default = "nvim";
        description = "Desktop entry icon name.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.enable = true;

    home.file = lib.mkIf (cfg.patchesPath != null) {
      ".config/nvim-manager/patches" = {
        source = cfg.patchesPath;
        recursive = true;
      };
    };

    xdg.desktopEntries = lib.mkIf (cfg.gui.enable && cfg.gui.configs != [ ]) launcherEntries;
  };
}
