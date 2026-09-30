// Hides the editor's cursor while the terminal (or tmux pane) is unfocused.
// pi draws the cursor itself, in reverse video after CURSOR_MARKER, and only
// turns on focus reporting in fullscreen mode, so this turns it on in regular
// mode and drops the reverse video on focus-out. In fullscreen, pi consumes the
// focus events before extensions see them, so this does nothing there.
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, type TUI } from "@earendil-works/pi-tui";

const FOCUS_REPORTING_ON = "\x1b[?1004h";
const FOCUS_REPORTING_OFF = "\x1b[?1004l";
const FOCUS_IN = "\x1b[I";
const FOCUS_OUT = "\x1b[O";
const REVERSE_VIDEO = "\x1b[7m";

let terminalFocused = true;

class FocusAwareEditor extends CustomEditor {
  render(width: number): string[] {
    const lines = super.render(width);
    if (terminalFocused) return lines;
    return lines.map((line) => line.replace(CURSOR_MARKER + REVERSE_VIDEO, CURSOR_MARKER));
  }
}

export default function (pi: ExtensionAPI) {
  let tui: TUI | undefined;

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setEditorComponent((editorTui, theme, keybindings) => {
      tui = editorTui;
      tui.terminal.write(FOCUS_REPORTING_ON);
      // pi copies padding and autocomplete settings over from its default editor.
      return new FocusAwareEditor(tui, theme, keybindings, { embedWorkingStatus: true });
    });

    ctx.ui.onTerminalInput((data) => {
      if (data !== FOCUS_IN && data !== FOCUS_OUT) return;
      terminalFocused = data === FOCUS_IN;
      tui?.requestRender();
      return { consume: true };
    });
  });

  pi.on("session_shutdown", () => {
    tui?.terminal.write(FOCUS_REPORTING_OFF);
    tui = undefined;
  });
}
