import Quickshell
import Quickshell.Io
import "components"
import "components/launcher"
import "core"
import "services"

// NotchShell — entry point.
//
// Three things go on screen and nothing else: one notch overlay per monitor,
// one launcher window on the focused monitor, and the IPC handlers that the
// Hyprland keybinds poke. All behaviour lives in the singletons (Config,
// Theme, UiState, CenterNav, Launcher) and in components/.
ShellRoot {
    // System events → transient notch statuses.
    EventBridge {}

    Variants {
        model: Quickshell.screens

        delegate: NotchWindow {}
    }

    // The launchers are a single window that follows the focused monitor,
    // not one per screen: only one of them can have the keyboard.
    LauncherWindow {}

    // ── IPC ──────────────────────────────────────────────────────
    // The shell has no keybinds of its own — a layer surface that grabbed
    // them would be taking them away from every real window. Hyprland owns
    // the keys and pokes these instead, which also makes every state in the
    // shell reachable from a script.

    IpcHandler {
        target: "notch"

        // What a keybind should call: the same thing tapping the notch does.
        function toggle(): void {
            UiState.toggleExpanded();
        }
        function open(): void {
            UiState.toExpanded();
        }
        function close(): void {
            UiState.dismiss();
        }
        // Raise a status in the notch from anywhere — a script that finished,
        // a backup that failed. `kind` picks the view; "notification" is the
        // general-purpose one and reads `summary` / `body`.
        function status(kind: string, summary: string, body: string): void {
            UiState.notify(kind, {
                summary: summary,
                body: body
            }, {
                priority: 2
            });
        }
    }

    IpcHandler {
        target: "launcher"

        function apps(): void {
            Launcher.show("apps");
        }
        function walls(): void {
            Launcher.show("walls");
        }
        function close(): void {
            Launcher.hide();
        }
    }
}
