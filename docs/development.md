# Development Guide

## Prerequisites

- **Zig 0.15.1** (or later 0.15.x)
  ```sh
  # macOS
  brew install zig

  # Verify
  zig version
  ```

## Build

```sh
# Debug build (fast compilation)
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseSafe

# Release small (size-optimized)
zig build -Doptimize=ReleaseSmall
```

The binary is output to `zig-out/bin/gctl`.

## Run

```sh
# Build and run in one step
zig build run

# Run the built binary directly
./zig-out/bin/gctl context
```

## Test

```sh
# Run all tests
zig build test

# Run specific test file
zig test src/cli/args.zig --dep cli --dep config -Mcli=src/cli/mod.zig -Mconfig=src/config/mod.zig

# Run with verbose output
zig build test --summary all
```

## Module Structure

| Module | Root | Dependencies |
|--------|------|--------------|
| `config` | `src/config/mod.zig` | — |
| `auth` | `src/auth/mod.zig` | config |
| `http` | `src/http/mod.zig` | auth |
| `cli` | `src/cli/mod.zig` | — |
| `context` | `src/context/mod.zig` | config |
| `providers` | `src/providers/mod.zig` | http, auth, context, cli |

## Adding a Provider

1. Create `src/providers/<name>.zig` with the capability vtable functions
2. Add to the provider registry in `src/providers/mod.zig`
3. Add token env var support in `src/auth/env.zig`
4. Add remote URL detection in `src/context/remote.zig`
5. Add API endpoint mappings in `docs/specs/providers.md`

## Code Style

- Zig standard library conventions
- No external dependencies (stdlib only)
- Error unions for all fallible operations
- Explicit allocator passing — no global allocators
- `defer` for resource cleanup
