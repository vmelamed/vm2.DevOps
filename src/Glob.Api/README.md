# Mathematical Equivalence Analysis

## Hypothesis

```text
/aaa/**/bbb/**/ccc/**/ddd
    ↓ (remove all ** after first)
/aaa/**/bbb/ccc/ddd
```

**These are semantically equivalent.**

## Testing a Counter-Example

Consider this filesystem:

```text
/aaa/bbb/ccc/ddd        (file)
/aaa/xxx/bbb/ccc/ddd    (file)
/aaa/xxx/yyy/bbb/ccc/ddd (file)
```

1. Pattern 1: `/aaa/**/bbb/**/ccc/**/ddd`

   - First `**` matches: `""`, `xxx`, `xxx/yyy`
   - After finding `bbb`, second `**` matches: `""`
   - After finding `ccc`, third `**` matches: `""`

Matches: All three files ✓

1. Pattern 2: `/aaa/**/bbb/ccc/ddd` (the reduced version)

  - `**` must match everything between `aaa` and `bbb`
  - Then must have literal `/ccc/ddd` immediately after
  - Matches: All three files ✓

Result: ✅ They ARE equivalent!

## Why This Works

The key insight is that `**` is greedy and flexible:

```text
/aaa/**/bbb/**/ccc
     ↓
/aaa/[any path]/bbb/[any path]/ccc
```

Because `**` can match paths that contain `bbb`, effectively "absorbing" the second `**`.

## Formal Proof

### Claim: `/A/**/B/**/C ≡ /A/**/B/C`

### Proof:

1. Forward (⟹): If path `P` matches `/A/**/B/**/C`

   - `P = /A/D₁/B/D₂/C` for some directory sequences `D₁`, `D₂`
   - Let `D = D₁/B/D₂` (concatenation treating `B` as a directory in the path)
   - Then `P = /A/D/C` where `D` contains `B`
   - So `P` matches `/A/**/B/C` with `** = D₁/B/D₂` ✓

1. Backward (⟸): If path P matches `/A/**/B/C`

   - `P = /A/D/B/C` where `D` is matched by `**`
   - We can split `D` at any point: `D = D₁/D₂`
   - Then `P = /A/D₁/B/D₂/C`
   - This matches `/A/**/B/**/C` with first `** = D₁, second ** = D₂` ✓

∴ They are equivalent. QED ∎