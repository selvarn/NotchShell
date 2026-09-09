**English** · [Русский](README.ru.md)

https://github.com/user-attachments/assets/59c4dd8a-f504-48e2-a2dd-36fd9b4a021f

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

```bash
curl -fsSL https://raw.githubusercontent.com/selvarn/NotchShell/master/install.sh | bash
```

The installer checks what you already have, lists what is missing and what each
missing piece would cost you (every optional package is exactly one feature — the
shell hides tiles it cannot drive), asks before installing anything, clones the shell
into `~/.config/quickshell`, and creates your `shell.conf` from the template. It does
**not** touch your Hyprland config: it prints the two lines to add and leaves the file
to you.

It also installs a `notchshell` command:

```bash
notchshell update      # pull the newest version — your settings are never touched
notchshell status      # version, what is running, your settings, what is missing
notchshell doctor      # the same checks plus the environment around the shell
notchshell config      # edit your settings
notchshell uninstall   # remove the program, asks before touching your settings
```

### Updating

```bash
notchshell update
```

It shows you what changed, fast-forwards the checkout and restarts the shell. Your
`shell.conf` is in `.gitignore`, so git cannot see it — an update has no code path
that could overwrite it. If a new version adds a setting, the updater says so and
points at the template; your config keeps working without it, because every option
has a default.

If you have edited the program itself, the updater stops and offers to stash your
changes rather than throwing them away.

<details>
<summary><b>Manual installation</b></summary>

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

The shell already calls it this way; the line is in `~/.config/quickshell/shell.conf`
if you ever need a different backend:
```ini
system {
    palette_command = wal --backend schemer2 -n -i %f
}
```

**5. Pick a wallpaper directory**

Wallpapers are looked up in `~/Pictures/Wallpapers` by default. The path lives in
`~/.config/quickshell/shell.conf`:

```ini
system {
    wallpapers = Pictures/Wallpapers
}
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

**8. The `notchshell` command** (optional, but it is how you update)
```bash
ln -sf ~/.config/quickshell/tools/notchshell ~/.local/bin/notchshell
```

</details>

---

## Configuration

Everything you can change lives in one file: **`~/.config/quickshell/shell.conf`**.
Save it and the running shell picks it up — no restart.

```ini
look {
    theme    = auto        # auto | dark | light
    accent   = auto        # auto | #7aa2f7
    rounding = soft        # sharp | soft | round
    font     = Inter
}

notch  { width = 172   height = 34   status_time = 1.7 }
panel  { width = 500   animation_speed = 1.0 }
launcher { width = 640   rows = 7   hidden_apps = }

system {
    terminal         = kitty -e
    wallpapers       = Pictures/Wallpapers
    keyboard_layouts = en, ru
}
```

That is the whole surface, on purpose. It is a short list of decisions rather than a
mirror of the internals: pick a roundness, not eleven radii; one animation speed, not
nine durations. Every value is validated and clamped, so a typo or a missing file
leaves the shell running on its defaults instead of breaking it.

The rest — the tone ladder derived from your wallpaper, the notch's shape schedule,
the motion curves — is the program's business and lives in `core/`. You are welcome
to edit it, but you should never have to.

**Yours vs the program's.** `shell.conf` is yours: it is git-ignored, so an update
cannot see it, let alone overwrite it. Everything git tracks is the program's, and an
update fast-forwards all of it — if you have edited those files by hand, the updater
stops and asks rather than discarding your work. Your Hyprland config is yours too:
nothing here ever writes to it.

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
