--[[
	jive.RemoteControlServer. 

	This module gives the possibility to send action events (such as "volume_up") from outside of jivelite
	
	See InputToActionMap.lua for all the possible actions to send.
		
	This way you don't have to implement a virtual keyboard/remote control to get jivelite to do that. 
	Just make a raw/telnet connection to port 9009 and send the actions (or via udp port 9009)
	
	initiate somewhere inside the function JiveMain:__init()
	
		jnt = NetworkThread()
		...
		local remoteControlServer = require("jive.RemoteControlServer")
		remoteControlServer:init(jnt, 9009) 
		...
		Framework:eventLoop(jnt:task())
	

--]]

-- not all declarations are necessary for this module to function, but remain as a result of past experiments

local Framework			= require("jive.ui.Framework")
local Event             = require("jive.ui.Event")
local SocketTcpServer	= require("jive.net.SocketTcpServer")
local SocketUdp			= require("jive.net.SocketUdp")
local Timer				= require("jive.ui.Timer");
local math 				= require("math")

local log				= require("jive.utils.log").logger("jive.RemoteControlServer")

local function split(str, sep)
	str = str .. sep -- if case there is no sep in str
	local result = {}
	for match in (str..sep):gmatch("(.-)"..sep) do
		table.insert(result, match)
	end
	table.remove(result)  -- remove last result (because of the extra sep at the end)
	return result
end

local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true  -- Value found
        end
    end
    return false  -- Value not found
end

local function printTable(tbl, indent, stack)
    indent = indent or 0
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            log:info(string.rep("  ", indent) .. key .. " : {")
			if contains(stack, value) then 
				log:info("...etc...") 
			else 
				table.insert(stack, value)
				printTable(value, indent + 1, stack) 
				table.remove(stack)
			end
            log:info(string.rep("  ", indent) .. "}")
        else
            log:info(string.rep("  ", indent) .. key, value)
        end
    end
end	

local function showTab() 
	printTable(jive.ui.style, 3, {})
end

local function dumpWindowStack(s)
    s = s or ""
    log:info("Window Stack:" .. s)
    for i, window in ipairs(Framework.windowStack) do
        if window then
            log:info(string.format("%d: %s", i, tostring(window)))
            for k, v in pairs(window) do
                log:info(string.format("  %s: %s", k, tostring(v)))
            end
        else
            log:info(string.format("%d: nil", i))
        end
    end
end

local listeners = {} --table of functions to be called when timer is decremented

local function notifyListeners(arg1, arg2)
	log:info('notifyListeners')
	for _, func in pairs(listeners) do
        func(arg1, arg2)
    end
	log:info('notifyListeners done')
end

local timer
local timerSeconds
local function initTimer(value, count)
	timerSeconds = value
	if count == nil then count = 120 end
	-- pre: timerSeconds >= 0 or nil
	-- every value of timerSeconds is immediately notified to the listeners (including nil)
	-- if it is nil, no new timer will be started
	-- if it is 0, every 0.5 second it will be notified (count times), after which nil will be notified
	-- if it > 0 every second the updated value is notified
	
	log:info('initTimer')
	function everySecond()
		if timerSeconds > 0 then
			timerSeconds = timerSeconds - 1
			log:info(timerSeconds)
		elseif count > 0 then -- notify timerSeconds (==0) every 1/2 second
			timer:restart(500)
			count = count - 1
		else  -- notify nil
			timer:stop()
			log:info('timer stopped')
			timer = nil
			timerSeconds = nil 
		end
		notifyListeners(timerSeconds, count)
	end
	if timer then --stop old timer
		timer:stop()
		timer = nil
		log:info('timer stopped')
	end
	notifyListeners(timerSeconds, count) -- first value will always be notified
	if timerSeconds then -- only if timerSeconds >= 0
		timer = Timer(1000, everySecond)
		log:info('timer started: ' .. timerSeconds)
		timer:start()
	end
end

local function _debug(func)
	local success, result = pcall(func)
	if not success then
		log:info("Error:", result)
		log:info(debug.traceback())
	end
end

local function messageHandler(message)
	log:info("New message (=action) received: ", message)
    local parts = split(message, ":")
	local msg = parts[1]
	local value = tonumber(parts[2]) -- can be nil
	log:info(msg)
	if msg == "quit" then
		appletManager:callService("disconnectPlayer")
		Framework:quit()
		return
	end
	if msg == "timer" then
		initTimer(value)
		return
	end
	if msg == "stack" then
		dumpWindowStack('')
		return
	end
	local actionEvent = Framework:newActionEventRCS(msg,value) 
	log:info("done")
	if actionEvent then
		Framework:pushEvent(actionEvent)
	else
		log:warn("action does not exist: ", message)
	end
end

local function messageHandlerMultiple(data)
    local parts = split(data, ";")
    log:info("Parts: " .. table.concat(parts, "; "))
    for _, part in ipairs(parts) do
        messageHandler(part)
    end
end

local function myUdpSink(chunk, err)
    if err then
        log:error("Error: " .. err)
    elseif chunk then
        log:info("Received: " .. chunk.data .. " from " .. chunk.ip .. ":" .. chunk.port)
		messageHandlerMultiple(chunk.data)
    end
end

local function createPump(client) 
    local luaSocket = client.t_sock --because client is of class net.SocketTcp
	log:info("creating pump for client")

    return function() -- this function will called by JNT regularly, see client:t_addRead
        local line, err = luaSocket:receive()
        if line then
            local data = line
            log:info("Received from client: " .. data)
            messageHandlerMultiple(data)
            return true  -- Continue reading
        elseif err == "closed" then
            log:info("Client disconnected")
            return false  -- see 'if not pumpFunction()...' in client:t_addRead
        elseif err ~= "timeout" then
            log:warn("Error receiving from client: " .. tostring(err))
            return false  -- see 'if not pumpFunction()...' in client:t_addRead
        end
        return true  -- Continue reading on timeout
    end
end

local mymodule = {
	
	init = function(self, jnt, port)
		local server
		local function accept()
			local client = server:t_accept()
			if client then
				log:info("New client connected")
				local pumpFunction = createPump(client)
				client:t_addRead(function()
					if not pumpFunction() then
						client:close()
						client:t_removeRead()  -- Remove read handler if pump returns false
					end
				end, 0) -- timeout must be 0, otherwise statement "tasks = task:resume() or tasks" in Framework.lua will block after 60 seconds of inactivity of a connected client, causing a freeze of the gui
			else 
				log:error("Client connection refused")
			end
		end
		
		log:info("Start listening on UDP port ", port)
		local udpListener = SocketUdp(jnt, myUdpSink, "UDPListener", port)
		if not udpListener then
			log:error("Failed to create listening udp socket on port ", port)
		end
		log:info("listening on UDP port ", port)	
		
		log:info("Starting server on port ", port)
		server = SocketTcpServer(jnt, "*", port, "RemoteControlServer")
		if not server then
			log:error("Failed to create tcp server on port ", port)
			return
		end
		log:info("Server started on port ", port)
		
		server:t_addRead(accept)
	end,
	
	getTimerSeconds = function(self)
		return timerSeconds
	end,
	
	getTimerTime = function(self)
		return timerSeconds and { min = math.floor(timerSeconds / 60), sec = timerSeconds % 60 } or nil
	end,
	
	getTimerMMSS = function(self)
		local timerTime = self:getTimerTime()
		if not timerTime then return nil end

		function padString(number)
			return number < 10 and "0" .. tostring(number) or tostring(number)
		end

		return {
			mins = padString(timerTime.min),
			secs = padString(timerTime.sec)
		}
	end,
	
	addListener = function(self, listener)
		table.insert(listeners, listener)
		log:info("listener added")
		return listener -- can be useful if an inline function is used, so you can get a reference to it, for removeListener
	end,
	
	removeListener = function(self, listener)
		for i, v in ipairs(listeners) do
			if v == value then
				table.remove(listeners, i)
				log:info("listener removed")
				return true  -- Entry removed successfully
			end
		end
		return false  -- Entry not found
	end
}
return mymodule