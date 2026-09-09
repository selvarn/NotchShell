**English** · [Русский](README.ru.md)

https://github.com/user-attachments/assets/f58f5b73-64a2-4866-af6e-d03596450f3d



## NotchShell

**A minimal, interactive system interface for Hyprland.**

The notch at the top of the screen appears only when it is actually needed. It shows the time, system events, the current workspace and the keyboard layout — and on interaction it unfolds into a compact Command Center.

The interface is built around one simple idea: **the UI is present only when you need it**. At rest there is nothing on screen. On a system event or a user action it appears quickly and shows exactly the information that matters.

Visually, NotchShell combines a deep black notch, a soft minimal UI and smooth, physical animations. The focus is on **simplicity, depth, motion and the feeling of a single physical interface element**.

The project is built for the Hyprland window manager and uses QuickShell to render the interface and talk to system components.

---

## Project status

> **NotchShell is in beta.**

This is my personal project. It started as something for my own working environment and gradually grew into a full interface for Hyprland.

I develop NotchShell alone and test it primarily on my own system. So I cannot guarantee that every feature will work on any hardware, distribution or Linux configuration.

**If something is missing for you, tell me about it.**

- an idea for a new feature;
- a suggestion for improving an existing one;
- an unusual use case;
- a bug you ran into;
- a problem with a particular configuration;
- a fix or a ready-made implementation.

**Don't hesitate to open an Issue or send a Pull Request.**

---

## Features

|                       |                                                                                                          |
| --------------------- | -------------------------------------------------------------------------------------------------------- |
| **Clock**             | Appears on hover and disappears as soon as the cursor leaves                                              |
| **Transient statuses**| Workspace, keyboard layout, volume                                                                        |
| **Player**            | MPRIS: album art, title, artist, playback controls and a seekable position bar                            |
| **Audio**             | `PipeWire`: output and input volume, mute and switching between real devices                              |
| **Network**           | NetworkManager via `nmcli`: connection list and VPN toggle                                                |
| **Night light**       | Screen temperature control through `hyprsunset`                                                           |
| **Notifications**     | Do Not Disturb and notification history through `dunstctl`                                                |
| **Power**             | Log out, sleep, reboot and shut down                                                                      |
| **App launcher**      | Its own `.desktop` scan, sorted by relevance and launch frequency, like `wofi`                            |
| **Wallpaper picker**  | Applies a wallpaper and recolors the whole shell automatically through `pywal`                            |
| **Calendar**          | A month view built into the interface                                                                     |

Every service probes its own availability at startup. If a component is not present on the system, the corresponding control hides itself and the grid reflows automatically. There should be no dead controls.

---

## Installation

**1. Install the packages**

Required packages:
```bash
sudo pacman -S hyprland quickshell ttf-jetbrains-mono-nerd
```

Optional packages. They are not required for the interface itself, but each one enables the matching functionality:
```bash
sudo pacman -S pipewire networkmanager dunst hyprsunset python-pywal awww inter-font
```

**2. Clone**

NotchShell is installed as a QuickShell configuration:
```bash
git clone https://github.com/selvarn/NotchShell.git ~/.config/quickshell
```

**3. Check that it runs**
```bash
qs
```
You may see nothing at all, and that is normal. Move the cursor to the top center of the screen. The notch should slide out.

**4. Pick a pywal backend**

If you installed `python-pywal`, the default backend is `wal`.
For a better color palette I recommend [`schemer2`](https://github.com/thefryscorer/schemer2). Any other backend works too, if you prefer one.

Installing schemer2:
```bash
go install github.com/thefryscorer/schemer2
```

Check that it works in a terminal:
```bash
schemer2 --help
```

Then set the backend in `~/.config/quickshell/Config.qml`:
```q
readonly property string paletteCommand: "wal --backend schemer2 -n -i %f"
```

**5. Pick a wallpaper directory**

If you use `awww`, wallpapers are looked up in `~/Pictures/Wallpapers` by default.
The path can be changed in `~/.config/quickshell/Config.qml`:

```q
readonly property string wallpaperDir: "Pictures/Wallpapers"
```

**6. Autostart**
```lua
-- hyprland.lua
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("awww-daemon") -- if awww is installed
end)
```

**7. Keybinds**

NotchShell has no keybinds of its own. Hyprland owns them and triggers the actions over IPC.

```lua
hl.bind(mainMod .. " + R",     hl.dsp.exec_cmd("qs ipc call launcher apps"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call notch toggle"))

-- if awww is installed
hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd("qs ipc call launcher walls"))
```

---

## Configuration

The main settings live in two files:
- `Config.qml`
- `Theme.qml`

Both are QML singletons, so changes apply on save and QuickShell reloads the configuration automatically.

Most parameters can be changed directly in these files. The comments inside them describe the available settings in more detail.

---
##  How to use it

**The notch:**

|Action|Result|
|---|---|
|Cursor to the top center|show the time|
|Click the notch|open the Command Center|
|Drag the notch down|unfold the Command Center at your own pace|
|Click away|close the Command Center|

**The launchers:**

| Key     | Action                            |
| ------- | --------------------------------- |
| ↑ ↓     | move the selection                |
| ← → Tab | switch between apps and wallpapers|
| Enter   | launch an app or apply a wallpaper|
| Esc     | close the launcher                |


**IPC**

Everything available through keybinds can also be called directly over IPC:
```
qs ipc call notch toggle
qs ipc call notch open
qs ipc call notch close

qs ipc call launcher apps
qs ipc call launcher walls
qs ipc call launcher close
```

You can also send a notification straight into the notch from any script:

```
qs ipc call notch status notification "test" "notification"
```
