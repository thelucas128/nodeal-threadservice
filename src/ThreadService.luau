local __ = _G()

--[=[
	@class ThreadService
	Lightweight coroutine pool that recycles threads to reduce allocation overhead.
	Threads are primed once and reused across :Spawn / :Defer / :Delay calls.
]=]
local ThreadService = {}

local MAX_POOL_SIZE: number = 256

local freeThreads: { thread } = {}
local poolCount: number = 0

local function returnThread(thread: thread)
	if poolCount < MAX_POOL_SIZE then
		poolCount += 1
		freeThreads[poolCount] = thread
	end
end

local function runCallback(callback: (...any) -> (), thread: thread, ...)
	-- xpcall keeps the thread alive so it can be recycled even when the callback errors.
	-- Without this, an erroring callback kills the coroutine and silently leaks it.
	xpcall(callback, function(err)
		task.spawn(error, debug.traceback(err, 2))
	end, ...)

	returnThread(thread)
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local function acquireThread(): thread
	if poolCount > 0 then
		local thread = freeThreads[poolCount]
		freeThreads[poolCount] = nil
		poolCount -= 1
		return thread
	end

	local thread = coroutine.create(yielder)
	coroutine.resume(thread)
	return thread
end

--[=[
	Immediately runs `callback` on a pooled thread.
]=]
function ThreadService:Spawn<T...>(callback: (T...) -> (), ...: T...)
	local thread = acquireThread()
	task.spawn(thread, callback, thread, ...)
end

--[=[
	Runs `callback` on a pooled thread after `delayTime` seconds.
]=]
function ThreadService:Delay<T...>(delayTime: number, callback: (T...) -> (), ...: T...)
	local args = { ... }
	local n = select("#", ...)

	task.delay(delayTime, function()
		self:Spawn(callback, table.unpack(args, 1, n))
	end)
end

--[=[
	Deferred version of :Spawn — runs after the current resumption cycle.
]=]
function ThreadService:Defer<T...>(callback: (T...) -> (), ...: T...)
	local thread = acquireThread()
	task.defer(thread, callback, thread, ...)
end

game:RegisterService("ThreadService", ThreadService)

--[=[
	@client
]=]
return __(ThreadService)
