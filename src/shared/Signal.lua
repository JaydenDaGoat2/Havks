-- Minimal signal implementation used by controllers to broadcast changes.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)

	local handlers = self._handlers
	return {
		Disconnect = function()
			if not handler.connected then
				return
			end
			handler.connected = false
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	} :: any
end

function Signal:Fire(...: any)
	-- Clone so handlers may disconnect themselves while firing.
	for _, handler in ipairs(table.clone(self._handlers)) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, handler in ipairs(self._handlers) do
		handler.connected = false
	end
	table.clear(self._handlers)
end

return Signal
