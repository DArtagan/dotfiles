// `/copy-code` and Alt+X copy the latest fenced code block to the clipboard, the
// way Ctrl+X copies the whole last message. The block comes from the message's
// markdown, so it's free of what the rendered view adds: pi's margin and
// code-block indent, and the hard breaks where long lines wrap.
import { copyToClipboard, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

interface CodeBlock {
  lang: string;
  code: string;
}

// Fenced code blocks in `markdown`, in order. Follows CommonMark: a fence is 3+
// backticks or tildes, closed by a fence of the same character at least as long,
// and the opening fence's indent is stripped from the content. Indenting fences
// past 3 spaces is allowed, so blocks nested in lists count. A block left open
// runs to the end, as it does while a message is streaming.
function codeBlocks(markdown: string): CodeBlock[] {
  const blocks: CodeBlock[] = [];
  let open: { fence: string; indent: number; lang: string; lines: string[] } | undefined;
  for (const line of markdown.split("\n")) {
    if (!open) {
      const m = /^(\s*)(`{3,}|~{3,})\s*([^`\s]*)[^`]*$/.exec(line);
      if (m) open = { fence: m[2], indent: m[1].length, lang: m[3], lines: [] };
      continue;
    }
    const close = /^\s*(`{3,}|~{3,})\s*$/.exec(line);
    if (close && close[1][0] === open.fence[0] && close[1].length >= open.fence.length) {
      blocks.push({ lang: open.lang, code: open.lines.join("\n") });
      open = undefined;
      continue;
    }
    const indent = /^ */.exec(line)![0].length;
    open.lines.push(line.slice(Math.min(indent, open.indent)));
  }
  if (open) blocks.push({ lang: open.lang, code: open.lines.join("\n") });
  return blocks;
}

// Code blocks of the active branch's assistant messages, latest last.
function branchCodeBlocks(ctx: ExtensionContext): CodeBlock[] {
  const blocks: CodeBlock[] = [];
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    for (const part of entry.message.content) {
      if (part.type === "text") blocks.push(...codeBlocks(part.text));
    }
  }
  return blocks;
}

async function copyCode(ctx: ExtensionContext, back: number) {
  const blocks = branchCodeBlocks(ctx);
  const block = blocks[blocks.length - back];
  if (!block) {
    ctx.ui.notify(
      blocks.length ? `Only ${blocks.length} code block(s) in this session` : "No code blocks in this session",
      "warning",
    );
    return;
  }
  await copyToClipboard(block.code);
  const lines = block.code.split("\n").length;
  ctx.ui.notify(`Copied ${block.lang || "code"} block (${lines} line${lines === 1 ? "" : "s"})`, "info");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("copy-code", {
    description: "Copy the latest code block; /copy-code 2 copies the one before it, and so on",
    handler: async (args, ctx) => {
      const back = args.trim() ? Number.parseInt(args, 10) : 1;
      if (!(back >= 1)) {
        ctx.ui.notify(`/copy-code takes a positive number, not "${args.trim()}"`, "error");
        return;
      }
      await copyCode(ctx, back);
    },
  });

  pi.registerShortcut("alt+x", {
    description: "Copy the latest code block",
    handler: (ctx) => copyCode(ctx, 1),
  });
}
