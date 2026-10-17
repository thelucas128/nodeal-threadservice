<p align="center">
  <a href="https://github.com/nodeal-framework">
    <img src="https://raw.githubusercontent.com/nodeal-framework/.github/main/assets/nodeal.svg" width="200" alt="Nodeal Framework" />
  </a>
</p>

# Nodeal ThreadService

Built for [Nodeal Framework](https://github.com/nodeal-framework) — lightweight coroutine pool that recycles threads to reduce allocation overhead ([nodeal.dev](https://www.nodeal.dev/)).

> Shared service — works on server and client.

## Why

Spawning lots of short-lived coroutines allocates constantly. `ThreadService` primes threads once and reuses them across `:Spawn` / `:Defer` / `:Delay` calls, capped at 256 pooled threads.

Erroring callbacks don't kill the pool: `xpcall` keeps the thread alive so it can be recycled, and the error is re-thrown async via `task.spawn(error, ...)` with a traceback.

## Install

Copy `src/ThreadService.luau` into your Nodeal project as a shared service module (Nodeal executes/registers it by default).

It self-registers on load:

```luau
game:RegisterService("ThreadService", ThreadService)
```

## Usage

```luau
local __ = _G()

local ThreadService = game:GetService("ThreadService")

-- Immediate run on a pooled thread
ThreadService:Spawn(function(name)
	print("hello", name)
end, "nodeal")

-- Deferred run (after current resumption cycle)
ThreadService:Defer(function()
	print("deferred")
end)

-- Delayed run (after 2 seconds, args preserved incl. nils)
ThreadService:Delay(2, function(a, b)
	print(a, b)
end, 1, nil)
```

> `Delay` captures varargs with `table.unpack(args, 1, n)` so trailing/`nil` arguments survive the wait.

## API

| Method | Signature | Description |
|---|---|---|
| `Spawn` | `Spawn(callback, ...)` | Immediately runs `callback` on a pooled thread |
| `Defer` | `Defer(callback, ...)` | Runs `callback` on a pooled thread via `task.defer` |
| `Delay` | `Delay(delayTime, callback, ...)` | Runs `callback` on a pooled thread after `delayTime` seconds |

## Notes

- Pool cap: `MAX_POOL_SIZE = 256` (tune in source if needed).
- Server + client: no `@server` / `@client` restriction in source (only `@client` doc annotation for the doc generator); register it in a shared location so both contexts get it.

## License

MIT — see `LICENSE`.
