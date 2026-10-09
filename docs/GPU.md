# GPU setup

This page covers what you need to do, if anything, so the Craft apps can use
your graphics card. It also covers what each step changes on your system and
how to undo it.

**Short version:** on NixOS with a working desktop you normally do nothing.
On another distribution you need one extra step, because programs built by
Nix cannot see your distribution's graphics drivers on their own.

## Contents

- [What this flake changes](#what-this-flake-changes)
- [Which platform needs what](#which-platform-needs-what)
- [How the apps use the GPU](#how-the-apps-use-the-gpu)
- [NixOS](#nixos)
- [Other distributions (Ubuntu, Fedora, Arch, …)](#other-distributions-ubuntu-fedora-arch-)
- [Virtual machines and computers without a GPU](#virtual-machines-and-computers-without-a-gpu)
- [Choosing the backend or GPU](#choosing-the-backend-or-gpu)
- [Checking your setup](#checking-your-setup)
- [What has been tested](#what-has-been-tested)

## What this flake changes

**Nothing about your graphics configuration.** The NixOS module never sets
`hardware.graphics`, `hardware.nvidia`, `services.xserver.videoDrivers` or
any driver option. It does only three things:

1. installs the app packages you enable;
2. sets `fonts.fontDir.enable = true` (only with `linkFonts`, the default);
3. links `/usr/share/fonts` to the system fonts (only with `linkFonts`).

The Home Manager module only adds the packages to `home.packages`.

So enabling this flake cannot break a working GPU setup. Every
GPU-related step below is one **you** choose to take. Each section says what
that step touches and how to undo it.

## Which platform needs what

| Platform                                | Do you need to do anything?                                                 | What it touches                                      |
| --------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------- |
| NixOS, AMD or Intel graphics            | No, as long as your desktop works (`hardware.graphics.enable`)              | Nothing                                              |
| NixOS, NVIDIA proprietary driver        | No, as long as the NVIDIA driver is set up for your desktop                 | Nothing                                              |
| NixOS, hybrid laptop, PRIME **sync**    | No. The apps run on the NVIDIA GPU like everything else                     | Nothing                                              |
| NixOS, hybrid laptop, PRIME **offload** | Optional: launch with `nvidia-offload` to use the NVIDIA GPU                | Nothing; per launch only                             |
| NixOS, no GPU or a VM                   | No, as long as `hardware.graphics.enable` is on; software rendering is used | Nothing                                              |
| Other distro, AMD / Intel / nouveau     | **Yes**: `targets.genericLinux.enable` (one `sudo` command) or nixGL        | `/run/opengl-driver` + one tmpfiles file, or nothing |
| Other distro, NVIDIA proprietary        | **Yes**: as above, plus your exact driver version                           | Same; must be refreshed after driver updates         |
| Other distro, hybrid laptop             | **Yes**: as above; use offload if you want the NVIDIA GPU                   | Same                                                 |
| Other distro, VM / no GPU               | **Yes**: same step; Mesa's software renderers are included                  | Same                                                 |
| WSL2                                    | Untested. Software rendering is expected to work                            | See [WSL2](#wsl2)                                    |

## How the apps use the GPU

All twelve apps draw their windows with [wgpu](https://wgpu.rs), a
cross-platform GPU library, through egui/eframe. On Linux, wgpu has two
backends:

- **Vulkan**, which it tries first;
- **OpenGL ES through EGL**, the fallback.

Neither library is bundled. The apps load them at startup from the Nix
package's library path: `vulkan-loader`, `libglvnd`, Wayland, X11 and
xkbcommon. Those libraries then look for the actual GPU driver in **one
place**, `/run/opengl-driver`, and not in `/usr/lib`. That path is the whole
story:

- **NixOS** fills `/run/opengl-driver` whenever `hardware.graphics.enable` is
  on, which every desktop environment does for you.
- **Other distributions** don't have `/run/opengl-driver`, so the apps find
  no driver until you add it, or wrap the apps so they look elsewhere.

**Software rendering.** If the drivers in `/run/opengl-driver` come from
Mesa, as on NixOS and with Home Manager's GPU module, they include two
software renderers: **lavapipe** (Vulkan) and **llvmpipe** (OpenGL). With
them, the apps still run on a machine with no usable GPU, just more slowly.

**PhotoCraft's own fallback.** PhotoCraft can also draw on the CPU instead of
the GPU:

- start it with `photocraft --safe-gpu` to do that for one launch;
- after a GPU failure it switches to the CPU renderer for the rest of the
  session by itself.

## NixOS

### AMD and Intel

Nothing to do. If your desktop runs, `hardware.graphics.enable` is already on,
and Mesa's drivers for your GPU are in `/run/opengl-driver`.

If you run a very minimal system with no desktop module, turn it on yourself:

```nix
hardware.graphics.enable = true;
```

### NVIDIA (proprietary driver)

Nothing extra. If you configured the NVIDIA driver the normal way, NVIDIA's
OpenGL, EGL and Vulkan drivers are in `/run/opengl-driver` and the apps use
them. That means `services.xserver.videoDrivers = [ "nvidia" ];` plus the
`hardware.nvidia` options your card needs.

**Don't change your NVIDIA configuration for these apps.** They need nothing
beyond what your desktop already uses.

### Hybrid laptops (Intel or AMD + NVIDIA)

It depends on your PRIME mode (`hardware.nvidia.prime`):

- **Sync mode** (`prime.sync.enable = true`): the NVIDIA GPU renders
  everything, these apps included. Nothing to do.
- **Offload mode** (`prime.offload.enable = true`): apps run on the
  integrated GPU by default, which saves battery. To run one on the NVIDIA
  GPU, first enable the helper:

  ```nix
  hardware.nvidia.prime.offload.enableOffloadCmd = true;
  ```

  Then launch through it:

  ```sh
  nvidia-offload photocraft
  ```

  `nvidia-offload` only sets environment variables for that one launch. It
  changes nothing system-wide.
- **Reverse sync:** the integrated GPU renders, so treat it like offload
  mode.

### NixOS without a GPU, or in a VM

Keep `hardware.graphics.enable = true`. Mesa's software renderers come with
it, and the apps render on the CPU. To force software rendering on a machine
that does have a GPU, see
[Choosing the backend or GPU](#choosing-the-backend-or-gpu).

### aarch64 (ARM) on NixOS

The same rules apply: `hardware.graphics.enable` plus whatever your board
needs. Apple silicon (Asahi), Raspberry Pi and other ARM GPUs are covered by
Mesa. This hasn't been tested on ARM hardware yet. The ARM builds are
compiled and checked in CI, but no GUI has been launched on ARM. See
[What has been tested](#what-has-been-tested).

### Using only Home Manager on NixOS

The GPU needs nothing extra, because the system already provides
`/run/opengl-driver`. You still need the system-level font link, though; see
[Fonts](../README.md#fonts) in the README.

## Other distributions (Ubuntu, Fedora, Arch, …)

Here the apps cannot see your distribution's drivers. There are two ways to
fix that. Both come from Home Manager, and the
[Home Manager manual](https://nix-community.github.io/home-manager/index.xhtml#sec-usage-gpu-non-nixos)
covers them in more depth.

| | Option 1: Home Manager GPU module | Option 2: nixGL wrapper |
| --- | --- | --- |
| Needs `sudo` | Once, plus again after some updates | Never |
| Changes to your system | Adds `/run/opengl-driver` and `/etc/tmpfiles.d/non-nixos-gpu.conf` | None |
| Effect on your distro's own apps | None. They don't look in `/run/opengl-driver` | None |
| Effect on the Craft apps | Work like on NixOS | Work; programs *started from* a wrapped app may misbehave |
| Recommended | Yes, if you have sudo | When you don't |

### Option 1: Home Manager GPU module (recommended)

Add to `home.nix`:

```nix
{
  targets.genericLinux.enable = true;
}
```

Run `home-manager switch`. The first time, it prints a command like this:

```text
GPU drivers require an update, run
  sudo /nix/store/…-non-nixos-gpu/bin/non-nixos-gpu-setup
```

Run that command once. It does two things:

- creates `/run/opengl-driver`, a link to Mesa's drivers from Nix;
- installs `/etc/tmpfiles.d/non-nixos-gpu.conf`, so the link is recreated at
  every boot (`/run` is cleared on reboot).

**What this does not touch:** your distribution's driver packages, `/usr/lib`,
`/etc/X11`, or anything your desktop or other apps use. Nothing outside Nix
reads `/run/opengl-driver`.

**After a Home Manager update,** `home-manager switch` may print the command
again when the Nix drivers change. Run it again. Until you do, the apps keep
using the previous drivers.

**To undo:**

```sh
sudo rm /run/opengl-driver
sudo rm /etc/tmpfiles.d/non-nixos-gpu.conf
```

Then remove `targets.genericLinux.enable` (or set
`targets.genericLinux.gpu.enable = false`) and run `home-manager switch`.

#### NVIDIA proprietary driver on another distribution

Mesa doesn't drive NVIDIA's proprietary stack, so Home Manager must fetch
NVIDIA's userspace libraries at **exactly** the version your kernel module
runs. Find it with:

```sh
cat /sys/module/nvidia/version
```

Then, in `home.nix`:

```nix
{
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.nvidia = {
    enable = true;
    version = "550.163.01";    # from /sys/module/nvidia/version
    sha256 = "sha256-…";       # see below
  };
}
```

Get `sha256` by fetching that exact driver from NVIDIA. The version appears
twice in the URL; on ARM, replace `x86_64` with `aarch64` in both places:

```sh
nix store prefetch-file \
  https://download.nvidia.com/XFree86/Linux-x86_64/550.163.01/NVIDIA-Linux-x86_64-550.163.01.run
```

> **⚠ Keep the version in sync.** When your distribution updates the NVIDIA
> driver, the kernel module changes. The Craft apps then fail to start until
> you update `version` and `sha256` (run the prefetch command again) and
> re-run the printed `sudo` command.
> Your desktop and every other app are unaffected. Make updating these two
> lines part of every NVIDIA driver update.

#### Hybrid laptops on another distribution

With Option 1, apps run on the GPU your distribution makes the default. To
use the NVIDIA GPU, use your distribution's offload launcher if it has one
(`prime-run` on Arch, `switcherooctl launch` on GNOME systems). You can also
set the variables `nvidia-offload` sets:

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only \
  __GLX_VENDOR_LIBRARY_NAME=nvidia photocraft
```

Home Manager can also install a `prime-offload` script; see
`targets.genericLinux.nixGL.prime` in the Home Manager manual.

### Option 2: nixGL (no sudo)

nixGL wraps each app so it finds drivers shipped from Nix. Nothing on the
system changes.

**Just trying an app**, with no Home Manager (Mesa: AMD, Intel or nouveau):

```sh
nix shell github:olafkfreund/nix-craftapps#photocraft \
  -c nix run github:nix-community/nixGL#nixGLIntel -- photocraft
```

`nixGLIntel` provides Mesa's OpenGL, and the apps use it through their
OpenGL fallback. For Vulkan, use `nixVulkanIntel` instead, or chain both. For
NVIDIA, use `nix run --impure github:nix-community/nixGL -- photocraft`;
`--impure` lets nixGL detect your driver version.

**With Home Manager,** add `nixGL` as a flake input
(`github:nix-community/nixGL`), pass `inputs` to Home Manager
(`extraSpecialArgs = { inherit inputs; };`), and wrap the apps:

```nix
{ config, inputs, ... }:
let
  craft = inputs.nix-craftapps.packages.x86_64-linux;
in
{
  targets.genericLinux.nixGL.packages = inputs.nixGL.packages;
  targets.genericLinux.nixGL.defaultWrapper = "mesa"; # or "nvidia"

  programs.craftapps = {
    enable = true;
    apps.photocraft = {
      enable = true;
      package = config.lib.nixGL.wrap craft.photocraft;
    };
    apps.wordcraft = {
      enable = true;
      package = config.lib.nixGL.wrap craft.wordcraft;
    };
  };
}
```

`config.lib.nixGL.wrap` does nothing until `nixGL.packages` is set. So the
same `home.nix` is safe to use on NixOS too.

**The trade-off:** a wrapped app runs with Nix's graphics libraries in its
environment. Programs it starts, such as an "open in browser" link, inherit
those libraries and can fail to start. The Craft apps themselves are fine.

### WSL2

Untested. WSLg provides the Wayland and X11 display. Hardware acceleration
under WSL goes through Microsoft's D3D12 drivers, which Nix's Mesa may not
pick up. With Option 1 or 2 above, the software renderers should work.
Reports are welcome.

## Virtual machines and computers without a GPU

The apps run with software rendering:

- **NixOS:** keep `hardware.graphics.enable = true`.
- **Other distributions:** use Option 1 or 2 above. The Mesa drivers they
  provide include the software renderers.

Expect lower frame rates, especially in FilmCraft and EffectCraft. If a VM
offers a virtual GPU (virtio-gpu / VirGL), Mesa uses it automatically.

## Choosing the backend or GPU

These environment variables apply to a single launch and change nothing
permanently.

| Variable | Values | Effect |
| --- | --- | --- |
| `WGPU_BACKEND` | `vulkan`, `gl` | Use only that backend. **Tested:** with `gl`, no Vulkan driver is loaded |
| `WGPU_POWER_PREF` | `low`, `high` | Prefer the integrated (`low`) or discrete (`high`) GPU, where both are visible to Vulkan |
| `WGPU_ADAPTER_NAME` | part of a GPU name | Pick the GPU whose name contains this text |

Examples:

```sh
WGPU_BACKEND=gl photocraft          # skip Vulkan, e.g. to work around a Vulkan driver bug
WGPU_POWER_PREF=high filmcraft      # ask for the discrete GPU
```

**Force software rendering**, even when a GPU is present (useful to rule out
a driver bug):

```sh
# Vulkan on the CPU (lavapipe)
VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/lvp_icd.x86_64.json deckcraft
# OpenGL on the CPU (llvmpipe)
WGPU_BACKEND=gl LIBGL_ALWAYS_SOFTWARE=1 deckcraft
```

On aarch64, the file is `lvp_icd.aarch64.json`.

App-specific switches:

- PhotoCraft: `--safe-gpu`.
- LightCraft: also reads `LIGHTCRAFT_GPU` and `LIGHTCRAFT_GPU_BACKEND`.
  These are undocumented upstream, so prefer the `WGPU_*` variables.

**Only `WGPU_BACKEND` and the two software-rendering commands have been
tested** on these packages. `WGPU_POWER_PREF` and `WGPU_ADAPTER_NAME` are
standard wgpu variables and are present in every app binary, but they
haven't been verified on a machine where they change the outcome.

## Checking your setup

Run these before blaming the apps. They only read; they change nothing.

```sh
# Are drivers where Nix programs look?
ls /run/opengl-driver/share/vulkan/icd.d/

# Which GPUs does Vulkan see? (from Nix, so it sees what the apps see)
nix shell nixpkgs#vulkan-tools -c vulkaninfo --summary

# Does EGL work?
nix shell nixpkgs#mesa-demos -c eglinfo -B

# Does the app itself start without a display? (no GPU needed)
photocraft-cli --version
```

If `/run/opengl-driver` doesn't exist:

- **NixOS:** `hardware.graphics.enable` is off.
- **Another distribution:** you haven't done Option 1 yet. With Option 2,
  `/run/opengl-driver` doesn't exist and that's expected.

If `vulkaninfo` lists only `llvmpipe`, the apps work, but on the CPU. Check
your driver setup above.

## What has been tested

Tested by launching the GUIs on real hardware with
`nix-craftapps` (October 2026):

| Setup | Result |
| --- | --- |
| NixOS, AMD Radeon (RX 7900 XTX), Hyprland/Wayland | Runs on the GPU via Vulkan (`radeon`). Also runs with `WGPU_BACKEND=gl`, with lavapipe, and with llvmpipe |
| NixOS, hybrid Intel + NVIDIA laptop, PRIME sync, proprietary driver 615.71, Hyprland/Wayland | Runs on the NVIDIA GPU in every mode tried |

Not yet tested, but documented from how the libraries and Home Manager work:

- PRIME offload;
- other distributions (Options 1 and 2);
- aarch64 GUIs;
- VMs with virtio-gpu;
- WSL2.

If you run the apps on one of these, an issue saying what worked helps the
next person.
