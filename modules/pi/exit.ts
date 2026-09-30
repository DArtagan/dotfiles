// `/exit` as a synonym for pi's built-in `/quit`. Unlike `/quit`, it waits for a
// running agent turn to finish before exiting.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("exit", {
    description: "Quit pi (same as /quit)",
    handler: async (_args, ctx) => {
      ctx.shutdown();
    },
  });
}
