// Runs any batch of tool calls that includes `write` or `edit` one call at a
// time, in the order the model issued them.
//
// pi runs the tool calls of one assistant message in parallel, and its per-file
// mutation queue only orders `write` and `edit` against each other. Models
// routinely batch an edit with the `bash` call that depends on it: run the
// script, test it, `git add -A && git commit`. pi then starts both at once, and
// the `bash` call can run before the file lands. `chmod` failing on a just-written script is the visible case; a
// commit that stages the pre-edit file and passes is the silent one.
//
// A tool with `executionMode: "sequential"` makes pi serialise its whole batch
// (https://github.com/earendil-works/pi/issues/3274), so this re-registers the
// built-ins with that set and nothing else changed. Batches without a file write
// stay parallel. Calls made from codemode scripts are not covered: there a
// sequential tool only waits for other sequential tools.
//
// The built-ins are rebuilt here with no options, as pi builds them in
// `createAllToolDefinitions` (dist/core/agent-session.js). If pi starts passing
// `write` or `edit` options there, pass the same ones here.
//
// Remove this once pi orders these calls itself: the built-in definitions in
// dist/core/tools/{write,edit}.js set `executionMode`, or pi gains a setting for
// sequential tool execution, which the agent's `toolExecution` option already
// supports but the CLI does not expose.
import {
  createEditToolDefinition,
  createWriteToolDefinition,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Only a fallback: both tools resolve paths against the session's cwd at call time.
  const cwd = process.cwd();
  pi.registerTool({ ...createWriteToolDefinition(cwd), executionMode: "sequential" });
  pi.registerTool({ ...createEditToolDefinition(cwd), executionMode: "sequential" });
}
