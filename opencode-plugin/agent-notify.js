import { spawn, spawnSync } from "node:child_process"
import { existsSync } from "node:fs"

// Maps OpenCode v2 events to tmux-agent-notify states.
// "busy" clears the marker (see scripts/notify.sh).
const STATE_BY_EVENT = {
  "session.idle": "done",
  "session.execution.failed": "error",
  "session.error": "error",
  "session.execution.interrupted": "busy",
  "session.execution.started": "busy",
  "permission.asked": "permission",
  "permission.replied": "busy",
  "form.created": "question",
  "form.replied": "busy",
  "form.cancelled": "busy",
}

const AGENT_COMMANDS = new Set(["opencode", "opencode-ai", "node", "bun"])

let cachedRoot

const resolveRoot = () => {
  if (process.env.TMUX_AGENT_NOTIFY_DIR) return process.env.TMUX_AGENT_NOTIFY_DIR
  const r = spawnSync("tmux", ["show-option", "-gqv", "@agent_notify_root"], { encoding: "utf8" })
  return (r.stdout || "").trim() || null
}

// Re-resolve lazily so the plugin keeps working if it loads before tmux sets
// @agent_notify_root, or if the tmux server starts after OpenCode.
const getScript = () => {
  if (!cachedRoot) cachedRoot = resolveRoot()
  if (!cachedRoot) return null
  const script = `${cachedRoot}/scripts/notify.sh`
  return existsSync(script) ? script : null
}

const tmux = (args) => {
  try {
    return spawnSync("tmux", args, { encoding: "utf8", timeout: 2000 })
  } catch {
    return null
  }
}

// OpenCode v2 runs plugins in a shared background server, so TMUX_PANE there is
// whatever pane happened to start the service — not the session's pane. Resolve
// the pane from the session's project directory instead.
const resolvePane = (directory) => {
  const fallback = process.env.TMUX_PANE || null
  const r = tmux(["list-panes", "-a", "-F", "#{pane_id}\t#{pane_current_path}\t#{pane_current_command}"])
  if (!r || r.status !== 0) return fallback

  const panes = (r.stdout || "")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [id, path, command] = line.split("\t")
      return { id, path: (path || "").replace(/\/+$/, ""), command }
    })

  const agents = panes.filter((p) => AGENT_COMMANDS.has(p.command))

  if (directory) {
    const dir = directory.replace(/\/+$/, "")
    const matches = panes.filter((p) => p.path && (p.path === dir || dir.startsWith(`${p.path}/`)))
    const agentMatches = matches.filter((p) => AGENT_COMMANDS.has(p.command))
    if (agentMatches.length) return agentMatches.sort((a, b) => b.path.length - a.path.length)[0].id
    if (matches.length === 1) return matches[0].id
  }

  if (fallback && agents.some((p) => p.id === fallback)) return fallback
  return agents.length === 1 ? agents[0].id : null
}

const notify = (state, pane) => {
  const script = getScript()
  if (!script || !pane) return
  try {
    spawn(script, ["opencode", state, pane], { stdio: "ignore", detached: true }).unref()
  } catch {
    // Notifications are best-effort.
  }
}

export default {
  id: "agent-notify",
  setup(ctx) {
    const directories = new Map()
    const seen = new Set()
    const controller = new AbortController()

    const eventDirectory = async (event) => {
      if (event.location && event.location.directory) return event.location.directory
      const sessionID = event.data && event.data.sessionID
      if (!sessionID) return null
      if (directories.has(sessionID)) return directories.get(sessionID)
      try {
        const session = await ctx.session.get({ sessionID })
        const directory = session && session.location && session.location.directory
        if (directory) directories.set(sessionID, directory)
        return directory || null
      } catch {
        return null
      }
    }

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const sessionID = event.data && (event.data.sessionID || (event.data.form && event.data.form.sessionID))
          if (sessionID && event.location && event.location.directory) {
            directories.set(sessionID, event.location.directory)
          }

          const state = STATE_BY_EVENT[event.type]
          if (!state) continue

          // The plugin is instantiated once per location and each instance
          // subscribes to the same global stream; act on each event once.
          if (seen.has(event.id)) continue
          seen.add(event.id)
          if (seen.size > 512) seen.clear()

          notify(state, resolvePane(await eventDirectory(event)))
        }
      } catch {
        // Stream aborted on unload.
      }
    })()

    return () => controller.abort()
  },
}
