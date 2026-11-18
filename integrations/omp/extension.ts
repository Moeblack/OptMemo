import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const execute = promisify(execFile);
const helper = join(dirname(fileURLToPath(import.meta.url)), "wake.py");
const memo = join(homedir(), ".optmem", "memo");
const interpreter = process.platform === "win32" ? "python" : "python3";
const command = `${interpreter} "${memo}"`;
const guidance = [
  "## OptMemo 使用说明",
  "本次记忆由用户通过 /memo 手动读取；不要自行重复唤醒。以下历史资料不恢复已被当前指令替代的旧规则。",
  `主会话需要操作记忆时，命令行入口为 ${command}；子代理不得执行 memo 或直接读写记忆库。`,
  "写入三步：1) 先 recall 搜是否记过，搜到就改它指向的 `文件§节`，不另写一份；没搜到就在合适文件新建一节。2) 写文件：现行值直接改在该节，旧值写进该节的更正记录。3) note：只记新的入口、规则、教训；已有入口的后续进展不重复 note。未落盘不得声称已保存。",
  "note 格式：一行，不超过 280 字节：`类型｜关键词｜位置｜要点`。类型为 入口/规则/教训/更正 四选一；关键词写对象名、别名、CT 号、IP、服务名，空格分隔，宁多勿少；位置写完整 `文件§节`（如 `~/.optmem/docs/<对象>/<对象>.md§节名`），用户口头规则且无文件写 `口头`；要点一句话：入口写这里有什么，规则和教训写结论，更正写\"旧 → 新\"。不写日期、事件经过、后续进展、\"详见\"等口头词。文档里不写 `#N`，长期地址一律写 `文件§节`。写好直接提交，长度由 memo 校验，不要事先用 python 统计字数。",
  "recall \"<正则>\"：检索原始历史；zoom <lo>-<hi>：复制现有摘要编号，逐层展开到原始条目。不要仅凭启动摘要猜测细节。",
  "nap <lo>-<hi> \"<合并行>\"：工具输出提示待合并时先完成再继续，以最新输出为准。必须保留：每条关键词（可去重）、每条 `文件§节`（同文件可合写 `x.md§操作,§更正记录`）、规则和教训的结论原文、更正的最终值。可以删：类型标记、要点说明、被更正的旧值。禁止新建 index 文件存放合并结果，禁止改写或推测原文没有的信息。放不下时依次舍弃：要点 → 合并同文件位置 → 最后才动关键词和规则；规则原文放不下就留\"规则：<关键词>\"，用 recall 去 LOG 取原文。\n- 直接提交：长度由 memo 校验，写好就交，不要事先用 python 统计字数；报超长再删减。",
  "不直接编辑或删除 memory/ 中的记录，交由 memo 管理。",
].join("\n");


export default function optMemo(pi: ExtensionAPI) {
  const schema = pi.zod.object({
    status: pi.zod.enum(["ready", "blocked", "error"]),
    count: pi.zod.number().int().nonnegative().nullable(),
    text: pi.zod.string(),
    memoryDir: pi.zod.string().nullable(),
  });

  // Only an explicit /memo invokes the reader. The trailing text is the
  // user's prompt, never a memo subcommand, shell command, or template.
  pi.registerCommand("memo", {
    description: "加载记忆；可直接在后面接本轮提示词，例如 /memo 你好",
    async handler(input, ctx) {
      if (ctx.agent.kind !== "main") {
        ctx.ui.notify("子代理不得执行 memo，所需记忆由主会话提供。", "warning");
        return;
      }
      await ctx.waitForIdle();
      const sessionId = ctx.sessionManager.getSessionId();
      const hasPrompt = input.trim().length > 0;
      let output: string;
      let failed = false;
      try {
        const { stdout } = await execute(interpreter, [helper, memo], {
          encoding: "utf8",
          env: { ...process.env, PYTHONUTF8: "1" },
          timeout: 60_000,
          maxBuffer: 8 * 1024 * 1024,
          windowsHide: true,
        });
        const snapshot = schema.parse(JSON.parse(stdout));
        failed = snapshot.status !== "ready";
        const status = failed
          ? `记忆读取${snapshot.status === "blocked" ? "等待归纳" : "失败"}，尚未完整载入。`
          : `已手动载入 ${snapshot.count} 条历史记忆的既定摘要视图。`;
        output = `${status}\n\n${guidance}\n\n${snapshot.text}`;
      } catch (error: unknown) {
        failed = true;
        const diagnostics: string[] = [];
        if (typeof error === "object" && error !== null) {
          if ("stdout" in error && typeof error.stdout === "string" && error.stdout.trim()) diagnostics.push(error.stdout.trim());
          if ("stderr" in error && typeof error.stderr === "string" && error.stderr.trim()) diagnostics.push(error.stderr.trim());
        }
        output = diagnostics.length ? diagnostics.join("\n") : error instanceof Error ? error.message : String(error);
      }
      if (ctx.sessionManager.getSessionId() !== sessionId) {
        ctx.ui.notify("会话已切换，未将记忆和提示词加入新会话。", "warning");
        return;
      }
      if (failed && hasPrompt) output += `\n\n记忆未加载成功，本轮提示词尚未发送：\n${input}`;
      pi.sendMessage({
        customType: "optmemo-command",
        content: `# /memo${failed ? "（未完成）" : ""}\n\n${output}`,
        display: true,
        details: { failed },
      }, { triggerTurn: false });
      // Memory is in the conversation before the user prompt is dispatched.
      // No explicit deliverAs: idle sendUserMessage starts this turn directly.
      if (!failed && hasPrompt) pi.sendUserMessage(input);
    },
  });
}
