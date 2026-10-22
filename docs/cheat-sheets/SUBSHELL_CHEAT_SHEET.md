# Bash Constructs That Create a Subshell

## **Always** creates a subshell

| Construct | Example |
|-----------|---------|
| **Pipe (left side)** | `cmd1 \| cmd2` — `cmd1` runs in subshell |
| **Parentheses** | `(cmd1; cmd2)` |
| **Command substitution** | `$(cmd)` or `` `cmd` `` |
| **Process substitution** | `<(cmd)` or `>(cmd)` |
| **Background job** | `cmd &` |
| **Coproc** | `coproc cmd` |

## **Sometimes** creates a subshell

| Construct | When |
|-----------|------|
| **Pipe (right side)** | Default in most shells; bash 4.2+ with `shopt -s lastpipe` runs the last command in the **current** shell (only in non-interactive scripts) |
| **Subshell function call** | `f() (...)` — function body in `()` instead of `{}` |

## Does **NOT** create a subshell

| Construct | Example |
|-----------|---------|
| **Braces (group command)** | `{ cmd1; cmd2; }` |
| **Here-string** | `cmd <<< "text"` |
| **Here-doc** | `cmd <<EOF ... EOF` |
| **Redirection** | `cmd > file` |
| **Source** | `source script.sh` or `. script.sh` |
| **`eval`** | `eval "cmd"` |
| **Builtin commands** | `cd`, `export`, `declare`, etc. |

<div style="page-break-after: always;"></div>

## `$(command)` vs `<(command)`

### `$(command)` — Command Substitution

- Captures **stdout** into a **string**
- Runs in a **subshell**
- Waits for the command to **complete** before substituting
- Trailing newlines are **stripped**
- Result is substituted **inline**

```bash
result=$(echo "hello")      # result="hello"
echo "$(printf "a\n\n\n")"  # prints "a" — trailing newlines gone
```

### `<(command)` — Process Substitution

- Creates a **file descriptor** (e.g., 63)
- Runs **asynchronously** — the command can still be producing output while the reader consumes it
- Preserves **all** output including trailing newlines
- Only works where a **filename** is expected
- **Bash-only** (not POSIX `sh`)

```bash
diff <(sort file1) <(sort file2)
while read -r line; do ... done < <(command)
```

### Key practical differences

| Aspect | `$(command)` | `<(command)` |
|---|---|---|
| Returns | String value | File path (`/dev/fd/N`) |
| Trailing `\n` | Stripped | Preserved |
| Memory | Entire output buffered in memory | Streamed |
| Large output | Can be slow / OOM | Handles well |
| Variable scope | Subshell — no side effects | `< <(cmd)` keeps loop in current shell |
| Usable in | Anywhere a string fits | Where a filename is expected |

<div style="page-break-after: always;"></div>

### The big gotcha: `while read` loops

```bash
# BAD — loop runs in a subshell, variable lost
echo "a" | while read -r line; do x="$line"; done
echo "$x"  # empty!

# GOOD — loop runs in current shell
while read -r line; do x="$line"; done < <(echo "a")
echo "$x"  # "a"
```

#### The sneaky ones (easy to forget)

```bash
# ❌ Variable lost — pipe creates subshell
echo "hello" | read var

# ✅ Variable preserved — here-string, no subshell
read var <<< "hello"

# ❌ Variable lost — pipe
cat file | while read line; do count=$((count+1)); done

# ✅ Variable preserved — redirection, no subshell
while read line; do count=$((count+1)); done < file

# ✅ Variable preserved — lastpipe (bash 4.2+, non-interactive)
shopt -s lastpipe
echo "hello" | read var  # var is preserved in current shell
```

##### Quick rule of thumb

**If data flows through `|`, the sending side runs in a subshell.** Everything else is usually safe for variable assignment.
