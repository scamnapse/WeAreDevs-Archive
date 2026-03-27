local s_lower = string.lower
local s_upper = string.upper
local s_find = string.find
local s_sub = string.sub
local s_gsub = string.gsub
local s_gmatch = string.gmatch
local s_char = string.char
local s_len = string.len
local m_randomseed = math.randomseed
local m_random = math.random
local t_remove = table.remove

local unpack = unpack
local type = type
local error = error
local assert = assert
local tonumber = tonumber
local setfenv = setfenv
local loadstring = loadstring
local next = next
local require = require
local setmetatable = setmetatable
local pcall = pcall
local wait = wait
local tick = tick
local typeof = typeof

local setreadonly = setreadonly
local getrawmetatable = getrawmetatable
local getobjects = getobjects
local checkcaller = checkcaller
local getelysianpath = getelysianpath
local readfile = readfile
local readrootfile = readrootfile
local writefile = writefile
local replaceclosure = replaceclosure
local elysianstep = elysianstep
local elysiancheckcb = elysiancheckcb
local elysianexecute = elysianexecute
local elysianonteleport = elysianonteleport
local elysianhttpget = elysianhttpget
local elysianhttppost = elysianhttppost
local elysianprintwelcome = elysianprintwelcome
local getdummydatamodel = getdummydatamodel
local freedummydatamodel = freedummydatamodel
local printconsole = printconsole
local getreg = getreg
local unlockmodulescript = unlockmodulescript
local newcclosure = newcclosure
local gni_getkey = gni_getkey
local isluau = isluau
local getnamecallmethod = getnamecallmethod
local checkclass = game.IsA
local getdescendants = game.GetDescendants
local cloneref = cloneref

local WhitelistedScripts = setmetatable({}, { __mode = "k" })
local LocalPlayer

rluadefs_init(Vector2.new(), Color3.new())
getgenv()["rluadefs_init"] = nil

local Services = setmetatable({}, {
	__index = function(self, i)
		local service = cloneref(game:GetService(i))
		self[i] = service
		return service
	end
})

-- Create GetObjects and add HttpGet filter
local RawInstanceIndex do
	local dummydatamodel = getdummydatamodel(game)
	local metatable = getrawmetatable(game)
	setreadonly(metatable, false)

	local old_index = metatable.__index
	local old_namecall = metatable.__namecall
	local old_newindex = metatable.__newindex

	local function filterindex(str)
		if (type(str) ~= "string") then return nil end
		return s_gsub(s_upper(s_sub(str, 1,1)) .. s_sub(str, 2), "%z", "")
	end

	local function urldecode(str)
		return s_gsub(str, "%%(%x%x)", function(m)
			return s_char(tonumber(m, 16))
		end)
	end

	local function isbadurl(url)
		url = urldecode(s_lower(url))

		for i, v in next, {"getauthticket", "placelauncher", "negotiate", "saml"} do
			if (s_find(url, v)) then
				return true
			end
		end

		return false
	end

	local function whitelistscripts(value, dontcheckdescendants)
		if (type(value) == "table") then
			for i, v in next, value do
				whitelistscripts(v)
			end
		elseif (typeof(value) == "Instance") then
			if (checkclass(value, "LocalScript")) then
				WhitelistedScripts[value] = true
			end

			if (not dontcheckdescendants) then
				for i, v in next, getdescendants(value) do
					if (checkclass(v, "LocalScript")) then
						WhitelistedScripts[v] = true
					end
				end
			end
		end
	end

	local function handleindex(self, index)
		if (type(index) == "string") then
			index = filterindex(index)

			if (index == "GetObjects") then
				return function(a, b)
					local objects = { getobjects(b) }
					whitelistscripts(objects)
					return objects
				end
			elseif (index == "HttpGet" or index == "HttpGetAsync" or index == "HttpPost" or index == "HttpPostAsync") then -- r u happy wally
				return function(a, b, c, d, e, f, g)
					if (isbadurl(b)) then return error("attempt to request potentially malicious url", 2) end

					local result
					local dummy = (typeof(a) == "Instance" and checkclass(a, "DataModel")) and dummydatamodel or a
					b = "res://3ds.is.cute/" .. b

					if (index == "HttpGet") then -- https://robloxapi.github.io/ref/class/DataModel.html#member-HttpGet
						result = old_index(a, "HttpGetAsync")(dummy, b, d, e)
					elseif (index == "HttpPost") then -- https://robloxapi.github.io/ref/class/DataModel.html#member-HttpPost
						result = old_index(a, "HttpPostAsync")(dummy, b, c, e, f, g)
					else
						result = old_index(a, index)(dummy, b, c, d, e, f, g)
					end

					for word in s_gmatch(result, "(%x+)") do
						if (s_len(word) == 264 or s_len(word) == 328) then
							return error("attempt to request potentially malicious url", 2)
						end
					end

					return result
				end
			end
		end

		return nil
	end

	metatable.__index = newcclosure(function(self, i)
		if (checkcaller() and checkclass(self, "DataModel")) then
			local result = handleindex(self, i)
			if (result ~= nil) then
				return result
			end
		end

		return old_index(self, i)
	end)

	if isluau() then
		metatable.__namecall = newcclosure(function(self, ...)
			local method = getnamecallmethod()

			if (checkcaller() and checkclass(self, "DataModel")) then
				local result = handleindex(self, method)
				if (result ~= nil) then
					return result(self, ...)
				end
			end

			return old_namecall(self, ...)
		end)
	else
		metatable.__namecall = newcclosure(function(self, ...)
			local args = {...}
			local method = t_remove(args)

			if (checkcaller() and checkclass(self, "DataModel")) then
				local result = handleindex(self, method)
				if (result ~= nil) then
					return result(self, unpack(args))
				end
			end
 
			return old_namecall(self, ...)
		end)
	end

	metatable.__newindex = newcclosure(function(self, i, v)
		if (checkcaller() and checkclass(self, "LocalScript") and i == "Source") then
			WhitelistedScripts[self] = true
		end

		return old_newindex(self, i, v)
	end)

	getgenv().whitelistscripts = whitelistscripts
	RawInstanceIndex = old_index
end

-- Clipboard
getgenv().Clipboard = {}
Clipboard.set = clipboard_set

setreadonly(Clipboard, true)

-- Input
do
	local vim = Services.VirtualInputManager
	local uis = Services.UserInputService
	local rss = Services.RunService.RenderStepped
	local mousemove = mousemove

	-- basic virtual key code -> roblox KeyCode map (for backwards compatibility)
	-- https://docs.microsoft.com/en-us/windows/desktop/inputdev/virtual-key-codes
	-- https://developer.roblox.com/api-reference/enum/KeyCode
	local map = {
		[0x20] = Enum.KeyCode.Space,
		[0xA0] = Enum.KeyCode.LeftShift,
		[0xA1] = Enum.KeyCode.RightShift,
		[0xA2] = Enum.KeyCode.LeftControl,
		[0xA3] = Enum.KeyCode.RightControl,
		[0xA4] = Enum.KeyCode.LeftAlt,
		[0xA5] = Enum.KeyCode.RightAlt,
	}

	local function v2kc(value)
		for i, v in next, Enum.KeyCode:GetEnumItems() do
			if (v.Value == value) then
				return v
			end
		end
	end

	for i = 0, 9 do map[i + 0x30] = v2kc(i + 48) end -- 0-9
	for i = 0, 25 do map[i + 0x41] = v2kc(i + 97) end -- A-Z
	for i = 0, 9 do map[i + 0x60] = v2kc(i + 256) end -- Keypad 0-9

	local function getkc(key)
		if (typeof(key) ~= "EnumItem") then
			key = map[key]
			assert(key ~= nil, "Unable to map key to KeyCode. Use a KeyCode instead.")
		end
		return key
	end

	getgenv().mouse1press = function(x, y)
		vim:SendMouseButtonEvent(x or uis:GetMouseLocation().X, y or uis:GetMouseLocation().Y, 0, true, nil, 0)
	end

	getgenv().mouse1release = function(x, y)
		vim:SendMouseButtonEvent(x or uis:GetMouseLocation().X, y or uis:GetMouseLocation().Y, 0, false, nil, 0)
	end

	getgenv().mouse2press = function(x, y)
		vim:SendMouseButtonEvent(x or uis:GetMouseLocation().X, y or uis:GetMouseLocation().Y, 1, true, nil, 0)
	end

	getgenv().mouse2release = function(x, y)
		vim:SendMouseButtonEvent(x or uis:GetMouseLocation().X, y or uis:GetMouseLocation().Y, 1, false, nil, 0)
	end

	getgenv().keypress = function(key, repeated)
		vim:SendKeyEvent(true, getkc(key), repeated ~= nil and repeated or false, nil)
	end

	getgenv().keyrelease = function(key)
		vim:SendKeyEvent(false, getkc(key), false, nil)
	end

	getgenv().mousemove = function(x, y, dx, dy)
		local mouse = uis:GetMouseLocation()
		return mousemove(x, y, dx or x - mouse.X, dy or y - mouse.Y)
	end

	getgenv().mousemoverel = function(dx, dy)
		local mouse = uis:GetMouseLocation()
		return mousemove(mouse.X + dx, mouse.Y + dx, dx, dy)
	end

	getgenv().mousescroll = function(amount, x, y)
		if (type(amount) == "boolean") then	amount = amount and 120 or -120	end
		assert(type(amount) == "number", "boolean or number expected")

		for i = 1, math.abs(math.floor(amount / 120)) do
			vim:SendMouseWheelEvent(x or uis:GetMouseLocation().X, y or uis:GetMouseLocation().Y, amount >= 0, nil)
			rss:wait()
		end		
	end

	getgenv().mouse1click = function(delay, x, y)
		if (not delay) then delay = 0 end
		mouse1press(x, y)
		wait(delay)
		mouse1release(x, y)
	end

	getgenv().mouse2click = function(delay, x, y)
		if (not delay) then delay = 0 end
		mouse2press(x, y)
		wait(delay)
		mouse2release(x, y)
	end
end

-- I/O
local loadrootfile do
	getgenv().loadfile = function(filename)
		local contents, err = readfile(filename)
		if not contents then return nil, err end
		return loadstring(contents)
	end

	function loadrootfile(filename)
		local contents, err = readrootfile(filename)
		if not contents then return nil, err end
		return loadstring(contents)
	end
end

-- Elysian IPC
do
	local eipc_send = eipc_send
	local HttpService = Services.HttpService
	local JSONEncode = HttpService.JSONEncode
	local JSONDecode = HttpService.JSONDecode

	getgenv().eipc_send = function(data, await_reply)
		local result, message = eipc_send(JSONEncode(HttpService, data), await_reply)

		if not result then
			return result, message
		end 

		if await_reply then -- a table was returned
			return result.success, JSONDecode(HttpService, result.data)
		end

		return result
	end
end

-- Hidden UI Container
do
	local container = Instance.new("Folder")
	local hui_init, hui_add, hui_remove = hui_init, hui_add, hui_remove
	
	hui_init(container)

	container.DescendantAdded:connect(function(child)
		if child:IsA("ScreenGui") or child:IsA("Message") then
			hui_add(child)
		end
	end)

	container.DescendantRemoving:connect(function(child)
		hui_remove(child)
	end)

	getgenv().gethui = function()
		return container
	end

	for i, v in next, {"hui_init", "hui_add", "hui_remove"} do
		getgenv()[v] = nil
	end
end

-- RBXScriptConnection Interface
do
	local rsc_init = rsc_init
	local rsc_action = rsc_action

	local rss = Instance.new("Part").Changed
	local rsc = rss:connect(function() end)
	rsc_init(rsc)

	local metatable = getrawmetatable(rsc)
	setreadonly(metatable, false)

	local old_index = metatable.__index
	local old_newindex = metatable.__newindex

	metatable.__index = newcclosure(function(self, i)
		if (checkcaller()) then
			if (i == "GetFunction") then
				return function(self) return rsc_action(self, 2) end
			elseif (i == "GetThread") then
				return function(self) return rsc_action(self, 3) end
			elseif (i == "LuaConnection") then
				return rsc_action(self, 1)
			elseif (i == "Enabled") then
				return rsc_action(self, 5)
			end
		end

		return old_index(self, i)
	end)

	metatable.__newindex = newcclosure(function(self, i, v)
		if (checkcaller()) then
			if (i == "Enabled") then
				assert(type(v) == "boolean", "boolean expected")
				rsc_action(self, 4, v)
				return
			end
		end

		return old_newindex(self, i, v)
	end)

	getgenv().rsc_init = nil
end

-- RBXScriptSignal Interface
do
	local rss_action = rss_action

	local rss = Instance.new("Part").Changed
	local metatable = getrawmetatable(rss)
	setreadonly(metatable, false)

	local old_index = metatable.__index

	metatable.__index = newcclosure(function(self, i)
		if (checkcaller()) then
			if (i == "Scriptable") then
				return rss_action(self, 2)
			elseif (i == "Connect" or i == "connect") then
				return function(self, ...)
					local before = rss_action(self, 1, true)
					local result = old_index(self, i)(self, ...)
					rss_action(self, 1, false)
					return result
				end
			elseif (i == "GetConnections") then
				return function(self)
					return assert(getconnections(self))
				end
			end
		end

		return old_index(self, i)
	end)
end

-- replaceclosure

do
	local backup_map = {}

	getgenv().replaceclosure = function(target, replacement)
		local backup = backup_map[target]

		if backup then
			if backup[1] ~= replacement then return nil, "this closure has already been replaced and can only be restored with its original" end
			backup_map[target] = nil
			return replaceclosure(target, replacement, false)
		else
			local result, err = replaceclosure(target, replacement, true)
			if not result then return result, err end
			backup_map[target] = { result, replacement }
			return result
		end
	end

	getgenv().restoreclosure = function(target)
		local backup = backup_map[target]

		if not backup then
			return false, "this closure has not been replaced"
		end

		backup_map[target] = nil
		return replaceclosure(target, backup[1], false)
	end
end


-- Other
getgenv().require = function(module)
	-- allows threads with security contexts of 6, 7, or 8 require modulescripts
	unlockmodulescript(module)
	return require(module)
end

getgenv().getnilinstances = function()
	local instances = {}

	for i, v in next, getreg()[gni_getkey()] do
		if (typeof(v) == "Instance" and v.Parent == nil) then
			instances[#instances + 1] = v
		end
	end

	return instances
end

getgenv().getsenv = function(instance)
	for i, v in next, getallthreads() do
		if (getthreadobject(v) == instance) then
			return gettenv(v)
		end
	end

	return nil
end

getgenv().getnspval = function(instance, property)
	local a, b = rfl_setscriptable(instance, property, true) 
	if not a then return nil, b end
	local value = instance[property]
	rfl_setscriptable(instance, property, b)
	return value
end 

getgenv().getunionassetid = function(union)
	return getnspval(union, "AssetId")
end

-- ;-)
getgenv().getlocals = secret234
getgenv().setlocal = secret300
getgenv().getupvals = secret953
getgenv().setupval = secret500

-- Elysian internals 
do
	local callbacks = getreg().ElysianCallbacks

	Services.RunService.RenderStepped:connect(function() -- BindToRenderStep(s_gsub("__elysiantick_XXXXXXXX", "X", function(c) return s_char(m_random(65, 122)) end), 0, elysianstep)
		elysianstep()

		for i, v in next, callbacks do
			if (elysiancheckcb(i)) then
				v()
				callbacks[i] = nil
				break
			end
		end
	end)
end

do
	local function CheckIfScriptExecutableAtLocation(object)
		local runnable

		if (LocalPlayer) then
			runnable = {	LocalPlayer:FindFirstChildOfClass"Backpack",
							LocalPlayer:FindFirstChildOfClass"PlayerGui",
							LocalPlayer:FindFirstChildOfClass"PlayerScripts",
							LocalPlayer.Character,
							Services.ReplicatedFirst }
		else
			runnable = { 	Services.ReplicatedFirst }
		end

		for i, v in next, runnable do
			if (v and object:IsDescendantOf(v)) then
				return true
			end
		end

		return false
	end

	-- TODO: this only affects scripts added to the game after elysian is injected (setting the source of existing scripts and reparenting/reenabling will have no effect)
	game.DescendantAdded:connect(function(child)	
		if (child:IsA"LocalScript") then
			child.Changed:connect(function(property)
				-- http://wiki.roblox.com/index.php?title=API:Class/LocalScript

				-- don't run if not whitelisted
				if (not WhitelistedScripts[child]) then return end

				-- only check to run if one of these properties changed
				if (not (property == "Source" or property == "LinkedSource" or property == "Disabled" or property == "Parent")) then return end

				 -- parented to nil, don't run
				if (not child.Parent) then return end

				 -- don't run if not in an executable location
				if (not CheckIfScriptExecutableAtLocation(child)) then return end

				-- don't run if disabled or empty
				if (child.Disabled or #child.Source == 0) then return end 

				elysianexecute(child.Source, child)
			end)
		end
	end)
end

-- Functions not available to the user
for i, v in next, {"getelysianpath", "elysianstep", "gni_getkey", "elysiancheckcb", "elysianhttpget", "elysianhttppost", "getdummydatamodel", "freedummydatamodel", "readrootfile"} do
	getgenv()[v] = nil
end

-- SaveInstance
do
	local sil = loadrootfile("saveinstance.lua")
	sil = sil and sil()

	local initiated = false

	local function init()
		local success, reason = sil.Init(RawInstanceIndex)
		if not success then
			printconsole("ERROR: Unable to initiate saveinstance() for reason: " .. tostring(reason), 255, 0, 0)
			sil = nil
		end
		initiated = true
	end

	--[[
		local defaultSettings = {
			DecompileMode = 0, -- 0 = don't decompile scripts, 1 = luadec, 2 = unluac
			NilInstances = false, -- save nil instances
			RemovePlayers = true, -- ignore players
			SavePlayerDescendants = false,
			DecompileTimeout = 10, -- unluac only
			UnluacMaxThreads = 5, -- the max number of java processes that should be running at one time (the higher this value is the faster the decompilation process)
			DecompileIgnore = {"StarterPlayer","Chat"} -- scripts inside these services are saved but not decompiled
		}
	]]

	getgenv().saveinstance = function(instance, filename, options)
		if sil then
			if not initiated then init() end
			return sil.Save(instance, filename, options)
		else
			error("saveinstance is not available (is saveinstance.lua in your elysian folder?)")
		end
	end

	getgenv().saveplace = function(filename, options)
		if sil then
			if not initiated then init() end
			return sil.Save(game, filename, options)
		else
			error("saveplace is not available (is saveinstance.lua in your elysian folder?)")
		end
	end
end

while (true) do
	LocalPlayer = Services.Players.LocalPlayer
	if (LocalPlayer) then break end
	Services.Players.PlayerAdded:wait()
end

LocalPlayer.OnTeleport:connect(function(state)
	if (state == Enum.TeleportState.InProgress) then
		printconsole("\nTeleport detected, reinitiating...", 255, 0, 0)
		elysianonteleport()
	end
end)

elysianprintwelcome()