# nvim-manager (NixOS-first)

Declarative Neovim config manager for NixOS/Home Manager. Provides:
- `nvim-manager` CLI (list/test/patch)
- Optional GUI launchers via Home Manager (`xdg.desktopEntries`)
- Patch linking into `~/.config/nvim-manager/patches`

## Use as a flake input

```nix
{
  inputs.nvim-manager.url = "path:/home/jajpater/Develop/nixos-config/temp/nvim-manager-nix";

  outputs = { self, nixpkgs, home-manager, nvim-manager, ... }:
  {
    # ...
    homeManagerModules.nvim-manager = nvim-manager.homeManagerModules.default;
  };
}
```

## Home Manager config

```nix
{ config, pkgs, ... }:
{
  imports = [
    # from your flake outputs
    # nvim-manager.homeManagerModules.default
  ];

  programs.nvim-manager = {
    enable = true;

    # Optional: create GUI launchers for selected configs
    gui.enable = true;
    gui.type = "neovide"; # or "nvim-qt"
    gui.configs = [ "NvChad" "LazyVim" "AstroNvim" ];

    # Optional: add extra tools (python3 not included by default)
    # extraPackages = with pkgs; [ python3 ];
  };
}
```

## CLI

```bash
nvim-manager list
nvim-manager test NvChad
nvim-manager patch NvChad nvchad-vim-uv-fix.patch
nvim-manager add NvChad https://github.com/NvChad/NvChad
nvim-manager remove NvChad
nvim-manager install-lazyvim
nvim-manager install-lazyvim --launcher lazyvim
nvim-manager install-astronvim
nvim-manager install-astronvim --launcher astronvim
nvim-manager install-nvchad
nvim-manager install-nvchad --remove-git
nvim-manager install-nvchad --launcher nvchad
nvim-manager install-nvchad --launcher nvchad --no-prompt
nvim-manager install MyConfig https://github.com/owner/repo --launcher myconfig
nvim-manager install-launcher lazyvim LazyVim
nvim-manager gui generate neovide
nvim-manager gui cleanup
nvim-manager gui list
```

## Environment

```bash
NVIM_CONFIG_DIR=~/.config
NVIM_MANAGER_PATCHES_DIR=~/.config/nvim-manager/patches
NVIM_MANAGER_GUI_DIR=~/.local/share/applications
NVIM_MANAGER_GUI_TYPE=neovide
NVIM_MANAGER_BIN_DIR=~/.local/bin
```

## Notes

- GUI launchers are managed declaratively via Home Manager.
- Patch files are linked to `~/.config/nvim-manager/patches` when enabled.
- Adding/removing configs via `nvim-manager` does not require a rebuild, but GUI launchers (if configured) update on rebuild.
- For ad-hoc launchers without rebuilds, use `nvim-manager gui generate` (writes `.desktop` files to `~/.local/share/applications`).
- `python3` is intentionally not included in defaults to avoid conflicts with custom Python environments; add it via `extraPackages` if needed.
