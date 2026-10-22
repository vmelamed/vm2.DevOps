# Bash Parameter Expansion Cheat Sheet

A compact guide to the `${…}` forms used throughout the vm2.DevOps bash library. Verified with bash 5.2; everything here
works in bash 4.4 and later, except where a section says otherwise.

Official reference: [Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
in the GNU Bash Reference Manual.

- [Bash Parameter Expansion Cheat Sheet](#bash-parameter-expansion-cheat-sheet)
  - [1. Defaults, Required Values, and Alternatives](#1-defaults-required-values-and-alternatives)
  - [2. Length](#2-length)
  - [3. Substrings and Slices](#3-substrings-and-slices)
  - [4. Removing a Prefix or Suffix](#4-removing-a-prefix-or-suffix)
  - [5. Search and Replace](#5-search-and-replace)
  - [6. Case Conversion](#6-case-conversion)
  - [7. Indirection](#7-indirection)
  - [8. The `@` Transformations](#8-the--transformations)
  - [9. Arrays: `@` versus `*`](#9-arrays--versus-)
  - [10. Things That Bite](#10-things-that-bite)
  - [References](#references)

## 1. Defaults, Required Values, and Alternatives

The colon means **"treat empty the same as unset"**. Without it, only *unset* triggers the form.

| Form         | `x` set, non-empty | `x` set, empty   | `x` unset        | Typical use                                  |
|:-------------|:-------------------|:-----------------|:-----------------|:---------------------------------------------|
| `${x:-word}` | `$x`               | `word`           | `word`           | default: `${VM2_REPOS:-$default}`            |
| `${x-word}`  | `$x`               | `""`             | `word`           | default for *missing* only: `${1-<missing>}` |
| `${x:=word}` | `$x`               | `word`, assigned | `word`, assigned | a default that sticks (not for `$1`, `$2`…)  |
| `${x=word}`  | `$x`               | `""`             | `word`, assigned |                                              |
| `${x:?msg}`  | `$x`               | error and exit   | error and exit   | "must be set": `${token:?no token}`          |
| `${x?msg}`   | `$x`               | `""`             | error and exit   |                                              |
| `${x:+word}` | `word`             | `""`             | `""`             | add only if present: `${a:+$a; }$b`          |
| `${x+word}`  | `word`             | `word`           | `""`             | "is it set at all?" (like `[[ -v x ]]`)      |

Under `set -u`, `${x-}` and `${x:-}` are the standard ways to read a possibly unset variable. None of the forms above
trips `set -u`.

## 2. Length

| Form         | Result                                  |
|:-------------|:----------------------------------------|
| `${#x}`      | the length of the string, in characters |
| `${#arr[@]}` | the number of array elements            |
| `${#arr[2]}` | the length of element 2                 |

## 3. Substrings and Slices

Offsets are 0-based.

| Form            | Result                                                                                |
|:----------------|:--------------------------------------------------------------------------------------|
| `${x:2}`        | from offset 2 to the end                                                              |
| `${x:2:3}`      | 3 characters, starting at offset 2                                                    |
| `${x: -3}`      | the last 3 characters. **The space is required**: `${x:-3}` is the default form of §1 |
| `${x:1:-1}`     | drop the first and the last character                                                 |
| `${arr[@]:1:2}` | array elements 1 and 2                                                                |
| `${@:2}`        | all positional parameters from `$2` on (as in `add_trap`)                             |

## 4. Removing a Prefix or Suffix

The patterns are **globs, not regular expressions**. One symbol removes the **shortest** match; doubled, it removes the
**longest**. To remember which is which: on the keyboard, `#` is left of `$` (the front), and `%` is right of it (the end).

| Form       | Removes               | Example, with `p=/a/b/file.tar.gz`      |
|:-----------|:----------------------|:----------------------------------------|
| `${p#*/}`  | shortest prefix match | `a/b/file.tar.gz`                       |
| `${p##*/}` | longest prefix match  | `file.tar.gz`, like `basename`          |
| `${p%/*}`  | shortest suffix match | `/a/b`, like `dirname`                  |
| `${p%%.*}` | longest suffix match  | `/a/b/file`                             |
| `${p%.*}`  | shortest suffix match | `/a/b/file.tar` (drops the last suffix) |
| `${p##*.}` | longest prefix match  | `gz` (the extension)                    |
| `${s% }`   | one trailing space    | the `_command` cleanup in `execute`     |

**Quote a variable that holds the pattern** to match it literally: `${path#"$prefix/"}`. Unquoted, any `*`, `?`, or
`[` inside `$prefix` acts as a glob character.

## 5. Search and Replace

| Form             | Replaces                                          |
|:-----------------|:--------------------------------------------------|
| `${x/pat/rep}`   | the first match                                   |
| `${x//pat/rep}`  | every match                                       |
| `${x/#pat/rep}`  | a match anchored at the start                     |
| `${x/%pat/rep}`  | a match anchored at the end                       |
| `${x//pat}`      | deletes every match (empty replacement)           |
| `${x//[!0-9]/}`  | keeps only the digits (as in `now_us`)            |
| `${arr[@]/#/-I}` | applies to every element: prefixes each with `-I` |

> [!WARNING]
> **Bash 5.2 and later: `&` in the replacement means "the matched text"** (the `patsub_replacement` option is on by
> default). `x=abc; echo "${x/b/[&]}"` prints `a[b]c`. Write `\&` for a literal ampersand, or quote it:
> `"${x/b/"&"}"`.

## 6. Case Conversion

| Form            | Result                                                   |
|:----------------|:---------------------------------------------------------|
| `${x^}`         | the first character to uppercase                         |
| `${x^^}`        | all characters to uppercase                              |
| `${x,}`         | the first character to lowercase                         |
| `${x,,}`        | all characters to lowercase (`case "${_option,,}"`)      |
| `${x~~}`        | toggles the case of every character                      |
| `${x^^[aeiou]}` | uppercases only the characters that match the pattern    |

## 7. Indirection

| Form          | Result                                                                                       |
|:--------------|:---------------------------------------------------------------------------------------------|
| `${!name}`    | the value of the variable *whose name* is in `$name` (for read-only loops over names)        |
| `${!prefix@}` | the names of all variables that start with `prefix`: `${!err_@}` lists every error code      |
| `${!arr[@]}`  | the indexes or keys of an array: `for repo in "${!target_repos[@]}"`                         |

To *write* through a name, use a nameref (`local -n`), not `${!…}`. See the CLAUDE.md section
[Variables and Dynamic Scope](../../CLAUDE.md#variables-and-dynamic-scope).

## 8. The `@` Transformations

Bash 4.4 and later; `U`, `u`, and `L` since bash 5.1.

| Form                         | Result                                                                    |
|:-----------------------------|:--------------------------------------------------------------------------|
| `${x@Q}`                     | quoted, so it can be read back as input: `'it'\''s'`                      |
| `${x@E}`                     | expands backslash escapes, like `$'…'` (`\n` becomes a newline)           |
| `${x@P}`                     | expands as a prompt string (`\u`, `\w`, …)                                |
| `${x@A}`                     | a `declare` statement that recreates `x`, with its attributes             |
| `${x@a}`                     | the attribute flags only: `r`, `x`, `i`, `a`, `A`, `n` ("is it readonly?") |
| `${x@U}`, `${x@u}`, `${x@L}` | the same as `^^`, `^`, and `,,`                                           |

## 9. Arrays: `@` versus `*`

| Form                        | Result                                                                          |
|:----------------------------|:--------------------------------------------------------------------------------|
| `"${arr[@]}"`               | each element as its own word, spaces intact. **Almost always the one you want** |
| `"${arr[*]}"`               | all elements joined into one string, separated by the first character of `IFS`  |
| `"$@"`, `"$*"`              | the same pair, for the positional parameters                                    |
| `(IFS=,; echo "${arr[*]}")` | joins with commas, in a subshell, so the caller's `IFS` is untouched            |

## 10. Things That Bite

1. **`${x:-3}` versus `${x: -3}`**: a default versus "the last 3 characters". The difference is one space.
1. **Patterns are globs, not regular expressions.** `*` means "anything", and there is no `+` or `\d`. For a regular
   expression, use `[[ $x =~ $re ]]` and `BASH_REMATCH`.
1. **`${x#$prefix}` without quotes** treats `$prefix` as a pattern. Quote it to match it literally (§4).
1. **`&` in replacements** under bash 5.2 (§5).
1. **Nesting works:** `${x:-${y:-fallback}}`, or `${_current[2]:+${_current[2]}$'\n'}` in `add_trap`.
1. **`${x:=…}` cannot assign to a positional parameter**: `${1:=foo}` is an error. Use `local _a=${1:-foo}`.

## References

- [Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) — GNU
  Bash Reference Manual, Free Software Foundation
- [The Shopt Builtin (`patsub_replacement`)](https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html) —
  GNU Bash Reference Manual, Free Software Foundation
