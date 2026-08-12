// Exercise node-pty through the exact Electron runtime shipped by the package.

const pty = require(process.env.HERMES_PTY_MODULE)
const shell = process.env.HERMES_PTY_SHELL
if (!shell) {
  throw new Error("HERMES_PTY_SHELL is required")
}

let output = ""
const child = pty.spawn(shell, ["-c", "printf hermes-desktop-pty-ok"], {
  name: "xterm-256color",
  cols: 80,
  rows: 24,
  cwd: process.cwd(),
  env: process.env,
})
const timer = setTimeout(() => {
  child.kill()
  console.error("timed out waiting for node-pty")
  process.exit(1)
}, 10000)
child.onData(data => {
  output += data
})
child.onExit(({ exitCode }) => {
  clearTimeout(timer)
  if (exitCode !== 0 || !output.includes("hermes-desktop-pty-ok")) {
    console.error(JSON.stringify({ exitCode, output }))
    process.exit(1)
  }
})
