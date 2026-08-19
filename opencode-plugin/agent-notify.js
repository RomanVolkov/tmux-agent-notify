
import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import { homedir } from "node:os"

const candidates = [
  process.env.TMUX_AGENT_NOTIFY_DIR,
  `${homedir()}/.tmux/plugins/tmux-agent-notify`,
  `${homedir()}/.config/tmux/plugins/tmux-agent-notify`,
].filter(Boolean)

const pluginDir = candidates.find((dir) => existsSync(`${dir}/scripts/notify.sh`))

const notify = (state) => {
  if (!pluginDir || !process.env.TMUX_PANE) return
  try {
    spawn(`${pluginDir}/scripts/notify.sh`, ["opencode", state], {
      stdio: "ignore",
      detached: true,
    }).unref()
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
