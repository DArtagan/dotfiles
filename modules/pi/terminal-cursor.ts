// Uses the terminal's own cursor in place of the one pi paints, so the terminal
// and tmux style it by focus: Alacritty hollows it when the window is
// unfocused, and tmux shows no cursor in inactive panes.
//
// pi paints its cursor as a reverse-video cell after CURSOR_MARKER, and moves
// the terminal cursor to that marker. Upstream PRs that strip the painted cell
// were auto-closed unreviewed (earendil-works/pi#5268, #9924; issue #3896), so
// this wraps TuiBase.extractCursorPosition, which isn't exported, to strip it.
// The terminal cursor is only turned on for frames where a painted cursor was
// stripped, so if pi changes, we fall back to its painted cursor rather than
// stacking the two (which Alacritty's default cursor colours render invisible).
// Turning it on here rather than with `showHardwareCursor` also survives
// `/reload`, which resets the TUI to that setting after session_start; the
// setting itself is overridden while this is loaded.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, type TUI } from "@earendil-works/pi-tui";

const PAINTED_CURSOR = CURSOR_MARKER + "\x1b[7m";

type Extract = (lines: string[], height: number) => unknown;

// `/reload` loads a fresh copy of this module, so keep pi's method on the TUI
// under a global symbol and always wrap that, rather than our previous wrapper.
const ORIGINAL = Symbol.for("dotfiles.terminal-cursor.extractCursorPosition");

type CursorTui = TUI & { extractCursorPosition?: Extract; [ORIGINAL]?: Extract };

// Returns false if pi no longer has the method this relies on.
function patch(tui: CursorTui): boolean {
  const extract = tui[ORIGINAL] ?? tui.extractCursorPosition;
  if (typeof extract !== "function") return false;
  tui[ORIGINAL] = extract;

  tui.extractCursorPosition = (lines, height) => {
    let marked = false;
    let stripped = false;
    for (let i = 0; i < lines.length; i++) {
      if (!lines[i].includes(CURSOR_MARKER)) continue;
      marked = true;
      if (lines[i].includes(PAINTED_CURSOR)) {
        lines[i] = lines[i].replace(PAINTED_CURSOR, CURSOR_MARKER);
        stripped = true;
      }
    }
    // Without a marker, pi hides the terminal cursor anyway.
    if (marked) tui.setShowHardwareCursor(stripped);
    return extract.call(tui, lines, height);
  };
  return true;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    // A widget factory is the only way an extension gets the TUI without
    // replacing a component. The widget renders nothing.
    let ok = true;
    ctx.ui.setWidget("terminal-cursor", (tui) => {
      ok = patch(tui);
      return { render: () => [], invalidate() {} };
    });
    if (!ok) {
      ctx.ui.notify(
        "terminal-cursor: pi's TUI has no extractCursorPosition; keeping pi's painted cursor",
        "warning",
      );
    }
  });
}
