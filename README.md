# ~/.local/bin

Personal CLI scripts and shims. On `$PATH` via `~/.zshrc`.

**Source of truth for `custom-scripts`:** each script file has `# Usage:` and `# Description:` headers in its first few lines. The table below is for browsing in an editor; run `custom-scripts` for terminal help.

## Header convention

```bash
#!/usr/bin/env bash
# Usage: myscript [args]
# Description: One-line summary of what it does.
```

## Scripts

| Script | Usage | Description |
|--------|-------|-------------|
| `awsctx` | `source awsctx [profile]` | Fuzzy AWS profile switch via [granted](https://granted.dev) `assume`. **Must be sourced** so credentials export to your shell. |
| `brewup` | `brewup` | Run `brew update`, `upgrade`, `cleanup`, and `autoremove`. |
| `cheat` | `cheat <command>` | Fetch a cheatsheet from [cht.sh](https://cht.sh). |
| `colima` | `colima start\|stop\|status\|restart` | Wrapper around Colima (Docker VM). Note: Homebrew's `colima` is earlier on `$PATH`; call this directly or alias it if you want the wrapper. |
| `copy` | `copy [text…]` or `echo foo \| copy` | Copy stdin or arguments to the clipboard. |
| `copyF` | `copyF <file>` | Copy **file contents** to the clipboard. |
| `copypath` | `copypath [path]` | Copy an absolute **path** to the clipboard. Default: current directory. |
| `custom-scripts` | `custom-scripts` | Print this help — list all scripts and shims with usage and descriptions. |
| `finder` | `finder [path]` | Open a path in Finder. Default: current directory. |
| `flushdns` | `flushdns` | Flush macOS DNS cache (requires `sudo`). |
| `kctx` | `kctx [context]` | Fuzzy-switch Kubernetes context (`fzf`). Uses `$KUBECONFIG`. |
| `kctx` | `kctx -n` | Fuzzy-switch namespace on the current context. |
| `killport` | `killport <port>` | Kill the process listening on a port. |
| `newGit` | `newGit <folder> [repo-name] [private\|public]` | Create a local git repo, initial commit, and push to GitHub via `gh`. |
| `newPy` | `newPy <project> [packages…]` | Scaffold a Python project with `uv` (init, venv, optional pip installs). |
| `paste` | `paste` | Print clipboard contents to stdout. |
| `port` | `port <port>` | Show what is listening on a port (read-only; pair with `killport`). |
| `restartSwipe` | `restartSwipe` | Restart the AeroSpace swipe LaunchAgent. |
| `serve` | `serve [port]` | Start `python3 -m http.server` and expose it via **ngrok**. Default port: `8000`. Requires ngrok auth. |

## Shims and symlinks

| Command | Target |
|---------|--------|
| `agent` | Cursor agent CLI |
| `cursor` | Cursor IDE shim (falls back to `agent`) |
| `cursor-agent` | Cursor agent CLI |
| `graphify` | Knowledge-graph tool (`uv` tool) |
| `graphify-mcp` | Graphify MCP server |
| `uv` | Python package manager |
| `uvx` | Run Python tools in ephemeral envs |

## Notes

- **Clipboard scripts** (`copy`, `copyF`, `copypath`, `paste`): macOS uses `pbcopy`/`pbpaste`; Linux fallbacks supported where installed.
- **`awsctx`**: run as `source awsctx`, not `./awsctx`.
- **`custom-scripts`**: reads `# Usage:` / `# Description:` headers from scripts; shims listed in the script itself.
- **`serve`**: Ctrl+C stops both the local server and the ngrok tunnel.
- **`newGit` / `newPy`**: usage text inside the scripts also references `newrepo` / `pynew` — filenames are the canonical command names today.
