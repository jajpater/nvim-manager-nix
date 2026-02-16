#!/usr/bin/env bash
set -euo pipefail

NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-$HOME/.config}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PATCHES_DIR="${NVIM_MANAGER_PATCHES_DIR:-$XDG_CONFIG_HOME/nvim-manager/patches}"

usage() {
  cat <<'USAGE'
ნvim-manager - Neovim configuration manager (NixOS-first)
=======================================================
Usage: nvim-manager <command> [args]

Commands:
  list                       List installed configs and CLI launchers
  test [config]              Test a config (headless)
  patch [config] [patch]     Apply a patch to a config
  add <name> <git-url>       Clone a config into ~/.config/<name>
  remove <name>              Remove a config directory
  install-lazyvim [--launcher NAME]            Install LazyVim starter into ~/.config/LazyVim
  install-astronvim [--launcher NAME]          Install AstroNvim template into ~/.config/AstroNvim
  install-nvchad [--remove-git] [--launcher NAME]  Install NvChad starter into ~/.config/NvChad
  install <name> <git-url> [--remove-git] [--launcher NAME] [--no-prompt]
                           Install any config repo into ~/.config/<name>
  install-launcher <name> <appname>  Create a launcher script in ~/.local/bin
  create-launcher <name> <appname>   Alias for install-launcher
  rename-launcher <old> <new>        Rename an existing launcher in ~/.local/bin
  gui generate [type]        Generate GUI launchers in ~/.local/share/applications
  gui cleanup                Remove generated GUI launchers
  gui list                   List generated GUI launchers
  help                       Show this help

Environment:
  NVIM_CONFIG_DIR            Base directory for NVIM_APPNAME configs (default: ~/.config)
  NVIM_MANAGER_PATCHES_DIR   Patch directory (default: ~/.config/nvim-manager/patches)
  NVIM_MANAGER_GUI_DIR       Desktop entries dir (default: ~/.local/share/applications)
  NVIM_MANAGER_GUI_TYPE      neovide or nvim-qt (default: neovide)
  NVIM_MANAGER_BIN_DIR       Launcher scripts dir (default: ~/.local/bin)
USAGE
}

list_configs() {
  echo "Available Neovim configurations:"
  echo "==============================="

  local found=0
  while IFS= read -r -d '' dir; do
    local name
    name="$(basename "$dir")"
    if [[ -f "$dir/init.lua" || -f "$dir/init.vim" ]]; then
      echo "OK  $name"
      found=1
    fi
  done < <(find "$NVIM_CONFIG_DIR" -maxdepth 1 -type d -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "(no configs found)"
  fi
}

list_launchers() {
  local dir
  dir="$(bin_dir)"
  echo "Installed CLI launchers:"
  echo "========================"
  echo "Directory: $dir"

  if [[ ! -d "$dir" ]]; then
    echo "(no launchers found)"
    return 0
  fi

  local found=0
  while IFS= read -r -d '' launcher; do
    local name appname
    name="$(basename "$launcher")"
    appname="$(sed -n 's/.*NVIM_APPNAME=\([^[:space:]]\+\).*/\1/p' "$launcher" | head -n1)"
    if [[ -n "$appname" ]]; then
      echo "OK  $name -> $appname"
      found=1
    fi
  done < <(find "$dir" -maxdepth 1 -type f -perm -u+x -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "(no launchers found)"
  fi
}

list_gui_launchers() {
  local dir
  dir="$(gui_dir)"
  echo "Installed GUI launchers:"
  echo "========================"
  echo "Directory: $dir"

  if [[ ! -d "$dir" ]]; then
    echo "(no GUI launchers found)"
    return 0
  fi

  local found=0
  while IFS= read -r -d '' desktop; do
    local file base type name
    file="$(basename "$desktop")"
    base="${file#nvim-manager-}"
    base="${base%.desktop}"
    type="${base%%-*}"
    name="${base#*-}"
    if [[ -n "$type" && -n "$name" && "$name" != "$base" ]]; then
      echo "OK  $file -> $type/$name"
      found=1
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name 'nvim-manager-*.desktop' -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "(no GUI launchers found)"
  fi
}

list_all() {
  list_configs
  echo
  list_launchers
  echo
  list_gui_launchers
}

add_config() {
  local name="$1"
  local url="$2"
  local target="$NVIM_CONFIG_DIR/$name"

  if [[ -z "$name" || -z "$url" ]]; then
    echo "Usage: nvim-manager add <name> <git-url>" >&2
    return 1
  fi

  if [[ -e "$target" ]]; then
    echo "ERR Target already exists: $target" >&2
    return 1
  fi

  echo "Cloning $url into $target..."
  if git clone "$url" "$target"; then
    echo "OK Added $name"
  else
    echo "ERR Clone failed"
    return 1
  fi
}

remove_config() {
  local name="$1"
  local target="$NVIM_CONFIG_DIR/$name"

  if [[ -z "$name" ]]; then
    echo "Usage: nvim-manager remove <name>" >&2
    return 1
  fi

  if [[ ! -d "$target" ]]; then
    echo "ERR Not found: $target" >&2
    return 1
  fi

  read -r -p "Remove $target? This deletes the directory. [y/N] " confirm
  if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Cancelled"
    return 1
  fi

  rm -rf "$target"
  echo "OK Removed $name"
}

gui_dir() {
  echo "${NVIM_MANAGER_GUI_DIR:-$HOME/.local/share/applications}"
}

gui_type() {
  echo "${NVIM_MANAGER_GUI_TYPE:-neovide}"
}

gui_list() {
  local dir
  dir="$(gui_dir)"
  echo "Generated launchers in $dir:"
  ls -1 "$dir"/nvim-manager-*.desktop 2>/dev/null || echo "(none)"
}

gui_cleanup() {
  local dir
  dir="$(gui_dir)"
  local removed=0
  for f in "$dir"/nvim-manager-*.desktop; do
    if [[ -f "$f" ]]; then
      rm -f "$f"
      removed=1
    fi
  done
  if [[ $removed -eq 1 ]]; then
    echo "OK Removed generated launchers"
  else
    echo "(none)"
  fi
}

gui_generate() {
  local type="${1:-$(gui_type)}"
  local dir
  dir="$(gui_dir)"

  if [[ "$type" != "neovide" && "$type" != "nvim-qt" ]]; then
    echo "ERR Unknown GUI type: $type (use neovide or nvim-qt)" >&2
    return 1
  fi

  mkdir -p "$dir"

  while IFS= read -r -d '' cfgdir; do
    local name
    name="$(basename "$cfgdir")"
    if [[ ! -f "$cfgdir/init.lua" && ! -f "$cfgdir/init.vim" ]]; then
      continue
    fi
    local desktop_file="$dir/nvim-manager-${type}-${name}.desktop"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${type^} (${name})
Comment=Neovim GUI using ${name} configuration
Exec=env NVIM_APPNAME=${name} ${type}
Icon=nvim
Terminal=false
Categories=Development;TextEditor;
MimeType=text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
Keywords=Text;editor;${type};${name};
StartupNotify=true
EOF
    chmod +x "$desktop_file"
  done < <(find "$NVIM_CONFIG_DIR" -maxdepth 1 -type d -print0 2>/dev/null)

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$dir" >/dev/null 2>&1 || true
  fi

  echo "OK Generated launchers in $dir"
}

bin_dir() {
  echo "${NVIM_MANAGER_BIN_DIR:-$HOME/.local/bin}"
}

install_launcher() {
  local name="$1"
  local appname="$2"
  local dir
  dir="$(bin_dir)"

  if [[ -z "$name" || -z "$appname" ]]; then
    echo "Usage: nvim-manager install-launcher <name> <appname>" >&2
    return 1
  fi

  mkdir -p "$dir"
  local target="$dir/$name"

  if [[ -e "$target" ]]; then
    echo "ERR Launcher already exists: $target" >&2
    return 1
  fi

  cat > "$target" <<EOF
#!/usr/bin/env bash
exec env NVIM_APPNAME=${appname} nvim "\$@"
EOF
  chmod +x "$target"
  echo "OK Created launcher: $target"
}

rename_launcher() {
  local old_name="$1"
  local new_name="$2"
  local dir
  dir="$(bin_dir)"

  if [[ -z "$old_name" || -z "$new_name" ]]; then
    echo "Usage: nvim-manager rename-launcher <old> <new>" >&2
    return 1
  fi

  local old_path="$dir/$old_name"
  local new_path="$dir/$new_name"

  if [[ ! -e "$old_path" ]]; then
    echo "ERR Launcher not found: $old_path" >&2
    return 1
  fi

  if [[ -e "$new_path" ]]; then
    echo "ERR Target launcher already exists: $new_path" >&2
    return 1
  fi

  mv "$old_path" "$new_path"
  echo "OK Renamed launcher: $old_name -> $new_name"
}

prompt_launcher_name() {
  local default_name="$1"
  local appname="$2"
  local no_prompt="${3:-0}"
  if [[ "$no_prompt" -eq 1 ]]; then
    return 1
  fi
  local answer
  read -r -p "Create launcher script? [y/N] " answer
  if [[ ! "$answer" =~ ^[yY]$ ]]; then
    return 1
  fi
  read -r -p "Launcher name [$default_name]: " name
  name="${name:-$default_name}"
  install_launcher "$name" "$appname"
}

auto_launcher_if_needed() {
  local launcher="$1"
  local default_name="$2"
  local appname="$3"
  local no_prompt="$4"
  if [[ -n "$launcher" ]]; then
    install_launcher "$launcher" "$appname"
    return 0
  fi
  if [[ "$no_prompt" -eq 1 ]]; then
    install_launcher "$default_name" "$appname"
    return 0
  fi
  prompt_launcher_name "$default_name" "$appname" "$no_prompt" || true
}

install_lazyvim() {
  local launcher=""
  local no_prompt=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --launcher)
        launcher="${2:-}"
        shift 2
        ;;
      --no-prompt)
        no_prompt=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  local target="$NVIM_CONFIG_DIR/LazyVim"
  local repo="https://github.com/LazyVim/starter"

  if [[ -e "$target" ]]; then
    echo "ERR Target already exists: $target" >&2
    return 1
  fi

  echo "Cloning LazyVim starter into $target..."
  if git clone "$repo" "$target"; then
    rm -rf "$target/.git"
    echo "OK LazyVim starter installed"
    echo "Next: NVIM_APPNAME=LazyVim nvim"
    auto_launcher_if_needed "$launcher" "lazyvim" "LazyVim" "$no_prompt"
  else
    echo "ERR Clone failed"
    return 1
  fi
}

install_astronvim() {
  local launcher=""
  local no_prompt=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --launcher)
        launcher="${2:-}"
        shift 2
        ;;
      --no-prompt)
        no_prompt=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  local target="$NVIM_CONFIG_DIR/AstroNvim"
  local repo="https://github.com/AstroNvim/template"

  if [[ -e "$target" ]]; then
    echo "ERR Target already exists: $target" >&2
    return 1
  fi

  echo "Cloning AstroNvim template into $target..."
  if git clone --depth 1 "$repo" "$target"; then
    rm -rf "$target/.git"
    echo "OK AstroNvim template installed"
    echo "Next: NVIM_APPNAME=AstroNvim nvim"
    auto_launcher_if_needed "$launcher" "astronvim" "AstroNvim" "$no_prompt"
  else
    echo "ERR Clone failed"
    return 1
  fi
}

install_nvchad() {
  local remove_git=0
  local launcher=""
  local no_prompt=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remove-git)
        remove_git=1
        shift
        ;;
      --launcher)
        launcher="${2:-}"
        shift 2
        ;;
      --no-prompt)
        no_prompt=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  local target="$NVIM_CONFIG_DIR/NvChad"
  local repo="https://github.com/NvChad/starter"

  if [[ -e "$target" ]]; then
    echo "ERR Target already exists: $target" >&2
    return 1
  fi

  echo "Cloning NvChad starter into $target..."
  if git clone --depth 1 "$repo" "$target"; then
    if [[ $remove_git -eq 1 ]]; then
      rm -rf "$target/.git"
      echo "OK NvChad starter installed (git metadata removed)"
    else
      echo "OK NvChad starter installed (git metadata kept)"
      echo "Remove later with: rm -rf \"$target/.git\""
    fi
    echo "Next: NVIM_APPNAME=NvChad nvim"
    auto_launcher_if_needed "$launcher" "nvchad" "NvChad" "$no_prompt"
  else
    echo "ERR Clone failed"
    return 1
  fi
}

install_generic() {
  local name="$1"
  local repo="$2"
  shift 2
  local remove_git=0
  local launcher=""
  local no_prompt=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remove-git)
        remove_git=1
        shift
        ;;
      --launcher)
        launcher="${2:-}"
        shift 2
        ;;
      --no-prompt)
        no_prompt=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -z "$name" || -z "$repo" ]]; then
    echo "Usage: nvim-manager install <name> <git-url> [--remove-git] [--launcher NAME] [--no-prompt]" >&2
    return 1
  fi

  local target="$NVIM_CONFIG_DIR/$name"
  if [[ -e "$target" ]]; then
    echo "ERR Target already exists: $target" >&2
    return 1
  fi

  echo "Cloning $repo into $target..."
  if git clone "$repo" "$target"; then
    if [[ $remove_git -eq 1 ]]; then
      rm -rf "$target/.git"
      echo "OK Installed (git metadata removed)"
    else
      echo "OK Installed (git metadata kept)"
    fi
    echo "Next: NVIM_APPNAME=$name nvim"
    auto_launcher_if_needed "$launcher" "${name,,}" "$name" "$no_prompt"
  else
    echo "ERR Clone failed"
    return 1
  fi
}

_test_config() {
  local config="$1"
  local nvim_appname=""

  if [[ $config != "default" ]]; then
    if [[ ! -d "$NVIM_CONFIG_DIR/$config" ]]; then
      echo "ERR Config not found: $NVIM_CONFIG_DIR/$config"
      return 1
    fi
    nvim_appname="$config"
  fi

  echo "Testing $config..."
  if NVIM_APPNAME="$nvim_appname" nvim --headless -c "qa" >/dev/null 2>&1; then
    echo "OK"
  else
    echo "ERR Failed"
    NVIM_APPNAME="$nvim_appname" nvim --headless -c "qa" 2>&1 | head -5 | sed 's/^/  /'
    return 1
  fi
}

test_config() {
  if [[ $# -eq 0 ]]; then
    echo "Select a config:" >&2
    echo "  - default" >&2
    list_configs | sed 's/^OK  /  - /' >&2
    return 1
  fi
  _test_config "$1"
}

apply_patch() {
  local config="$1"
  local patch_name="$2"
  local config_dir="$NVIM_CONFIG_DIR/$config"
  local patch_file="$PATCHES_DIR/$patch_name"

  if [[ ! -d "$config_dir" ]]; then
    echo "Error: Config not found: $config_dir" >&2
    return 1
  fi
  if [[ ! -f "$patch_file" ]]; then
    echo "Error: Patch not found: $patch_file" >&2
    return 1
  fi

  echo "Applying patch $patch_name to $config..."
  if [[ -f "$config_dir/init.lua" ]]; then
    cp "$config_dir/init.lua" "$config_dir/init.lua.backup.$(date +%Y%m%d_%H%M%S)"
  fi

  if (cd "$config_dir" && patch -p1 < "$patch_file"); then
    echo "OK Patch applied"
  else
    echo "ERR Patch failed"
    return 1
  fi
}

main() {
  case "${1:-}" in
    list)
      list_all
      ;;
    add)
      shift
      add_config "${1:-}" "${2:-}"
      ;;
    remove)
      shift
      remove_config "${1:-}"
      ;;
    install-lazyvim)
      shift
      install_lazyvim "$@"
      ;;
    install-astronvim)
      shift
      install_astronvim "$@"
      ;;
    install-nvchad)
      shift
      install_nvchad "$@"
      ;;
    install)
      shift
      install_generic "$@"
      ;;
    install-launcher)
      shift
      install_launcher "${1:-}" "${2:-}"
      ;;
    create-launcher)
      shift
      install_launcher "${1:-}" "${2:-}"
      ;;
    rename-launcher)
      shift
      rename_launcher "${1:-}" "${2:-}"
      ;;
    test)
      shift
      test_config "$@"
      ;;
    patch)
      shift
      if [[ $# -ne 2 ]]; then
        echo "Usage: nvim-manager patch <config> <patch>" >&2
        exit 1
      fi
      apply_patch "$1" "$2"
      ;;
    gui)
      shift
      case "${1:-}" in
        generate)
          shift
          gui_generate "${1:-}"
          ;;
        cleanup)
          gui_cleanup
          ;;
        list)
          gui_list
          ;;
        *)
          echo "Usage: nvim-manager gui generate [neovide|nvim-qt]" >&2
          echo "       nvim-manager gui cleanup" >&2
          echo "       nvim-manager gui list" >&2
          ;;
      esac
      ;;
    help|--help|-h|"")
      usage
      ;;
    *)
      echo "Unknown command: $1" >&2
      echo
      usage
      exit 1
      ;;
  esac
}

main "$@"
