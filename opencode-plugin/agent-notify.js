import { spawn, spawnSync } from "node:child_process"
import { existsSync } from "node:fs"

const resolveRoot = () => {
  if (process.env.TMUX_AGENT_NOTIFY_DIR) return process.env.TMUX_AGENT_NOTIFY_DIR
  const r = spawnSync("tmux", ["show-option", "-gqv", "@agent_notify_root"], { encoding: "utf8" })
  return (r.stdout || "").trim() || null
}

const root = resolveRoot()
const script = root ? `${root}/scripts/notify.sh` : null
const usable = script && existsSync(script)

const notify = (state) => {
  if (!usable || !process.env.TMUX_PANE) return
  try {
    spawn(script, ["opencode", state], { stdio: "ignore", detached: true }).unref()
  } catch {
  }
}

export const AgentNotify = async () => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") notify("done")
      else if (event.type === "session.error") notify("error")
      else if (event.type.startsWith("permission.")) notify("permission")
    },
  }
}
