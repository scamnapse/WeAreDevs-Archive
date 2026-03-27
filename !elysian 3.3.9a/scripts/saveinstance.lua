-- Made by Moon
local Main,Serializer,API,Settings,DefaultSettings,env

local service = setmetatable({},{__index = function(self,name)
	local serv = game:GetService(name)
	self[name] = serv
	return serv
end})

DefaultSettings = {
	Serializer = {
		_Recurse = true,
		Decompile = false,
		NilInstances = false,
		RemovePlayerCharacters = true,
		SavePlayers = false,
		DecompileTimeout = 10,
		MaxThreads = 3,
		DecompileIgnore = {"Chat","CoreGui","CorePackages"},
		ShowStatus = true,
		IgnoreDefaultProps = true,
		IsolateStarterPlayer = true,
	}
}

Serializer = (function()
	local Serializer = {}

	local oldIndex,getnspval,getbspval,gethiddenprop,getnilinstances,getpcd,encodeBase64
	local classes,saveProps,testInsts = {},{},{}
	local tostring = tostring
	local format = string.format
	local gsub = string.gsub
	local sub = string.sub
	local getChildren = game.GetChildren
	local isa = game.IsA
	local components = CFrame.new(0,0,0).GetComponents
	local httpService = service.HttpService
	local urlEncode = httpService.UrlEncode
	local gameId

	local propBypass = {
		["BasePart"] = {
			["Size"] = true,
			["Color"] = true,
		},
		["Part"] = {
			["Shape"] = true
		},
		["Fire"] = {
			["Heat"] = true,
			["Size"] = true,
		},
		["Smoke"] = {
			["Opacity"] = true,
			["RiseVelocity"] = true,
			["Size"] = true,
		},
		["DoubleConstrainedValue"] = {
			["Value"] = true
		},
		["IntConstrainedValue"] = {
			["Value"] = true
		},
		["TrussPart"] = {
			["Style"] = true
		}
	}

	local propFilter = {
		["BaseScript"] = {
			["LinkedSource"] = true
		},
		["ModuleScript"] = {
			["LinkedSource"] = true
		},
		["Players"] = {
			["CharacterAutoLoads"] = true
		},
		["Instance"] = {
			["SourceAssetId"] = true
		}
	}
	
	local xmlReplacePattern = "['\"<>&\0]"
	
	local xmlReplace = {
		["'"] = "&apos;",
		["\""] = "&quot;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
		["\0"] = ""
	}

	local serviceBlacklist = {
		["CoreGui"] = true,
		["CorePackages"] = true,
	}
	
	local nilClassParents = {
		["Attachment"] = "Part",
		["Bone"] = "Part",
		["Animator"] = "Humanoid",
		["SurfaceAppearance"] = "MeshPart"
	}
	
	local valueConverters = {
		["bool"] = function(name,val)
			return '\n<bool name="'..name..'">'..(val and "true" or "false")..'</bool>'
		end,
		["int"] = function(name,val)
			return format('\n<int name="%s">%d</int>',name,val)
		end,
		["int64"] = function(name,val)
			return format('\n<int64 name="%s">%d</int64>',name,val)
		end,
		["float"] = function(name,val)
			return format('\n<float name="%s">%.12f</float>',name,val)
		end,
		["double"] = function(name,val)
			return format('\n<double name="%s">%.12f</double>',name,val)
		end,
		["string"] = function(name,val)
			return '\n<string name="'..name..'">'..gsub(val,xmlReplacePattern,xmlReplace)..'</string>'
		end,
		["BrickColor"] = function(name,val)
			return format('\n<int name="%s">%d</int>',name,val.Number)
		end,
		["Vector2"] = function(name,val)
			return format('\n<Vector2 name="%s">\n<X>%.12f</X>\n<Y>%.12f</Y>\n</Vector2>',name,val.X,val.Y)
		end,
		["Vector3"] = function(name,val)
			return format('\n<Vector3 name="%s">\n<X>%.12f</X>\n<Y>%.12f</Y>\n<Z>%.12f</Z>\n</Vector3>',name,val.X,val.Y,val.Z)
		end,
		["CFrame"] = function(name,val)
			return format('\n<CoordinateFrame name="%s">\n<X>%.12f</X>\n<Y>%.12f</Y>\n<Z>%.12f</Z>\n<R00>%.12f</R00>\n<R01>%.12f</R01>\n<R02>%.12f</R02>\n<R10>%.12f</R10>\n<R11>%.12f</R11>\n<R12>%.12f</R12>\n<R20>%.12f</R20>\n<R21>%.12f</R21>\n<R22>%.12f</R22>\n</CoordinateFrame>',name,components(val))
		end,
		["Content"] = function(name,val)
			if sub(val,1,15) == "rbxgameasset://" then
				val = format("https://assetdelivery.roblox.com/v1/asset?universeId=%d&assetName=%s&skipSigningScripts=1",gameId,urlEncode(httpService,sub(val,16)))
			end
			return '\n<Content name="'..name..'"><url>'..gsub(val,xmlReplacePattern,xmlReplace)..'</url></Content>'
		end,
		["UDim"] = function(name,val)
			return format('\n<UDim name="%s">\n<S>%.12f</S>\n<O>%d</O>\n</UDim>',name,val.Scale,val.Offset)
		end,
		["UDim2"] = function(name,val)
			local x = val.X
			local y = val.Y
			return format('\n<UDim2 name="%s">\n<XS>%.12f</XS>\n<XO>%d</XO>\n<YS>%.12f</YS>\n<YO>%d</YO>\n</UDim2>',name,x.Scale,x.Offset,y.Scale,y.Offset)
		end,
		["Color3"] = function(name,val)
			return format('\n<Color3 name="%s">\n<R>%.12f</R>\n<G>%.12f</G>\n<B>%.12f</B>\n</Color3>',name,val.R,val.G,val.B)
		end,
		["NumberRange"] = function(name,val)
			return '\n<NumberRange name="'..name..'">'..tostring(val)..'</NumberRange>'
		end,
		["NumberSequence"] = function(name,val)
			return '\n<NumberSequence name="'..name..'">'..tostring(val)..'</NumberSequence>'
		end,
		["ColorSequence"] = function(name,val)
			return '\n<ColorSequence name="'..name..'">'..tostring(val)..'</ColorSequence>'
		end,
		["Rect"] = function(name,val)
			local min,max = val.Min,val.Max
			return format('\n<Rect2D name="%s">\n<min>\n<X>%.12f</X>\n<Y>%.12f</Y>\n</min>\n<max>\n<X>%.12f</X>\n<Y>%.12f</Y>\n</max>\n</Rect2D>',name,min.X,min.Y,max.X,max.Y)
		end,
		["PhysicalProperties"] = function(name,val)
			if val then
				return format('\n<PhysicalProperties name="%s">\n<CustomPhysics>true</CustomPhysics>\n<Density>%.12f</Density>\n<Friction>%.12f</Friction>\n<Elasticity>%.12f</Elasticity>\n<FrictionWeight>%.12f</FrictionWeight>\n<ElasticityWeight>%.12f</ElasticityWeight>\n</PhysicalProperties>',name,val.Density,val.Friction,val.Elasticity,val.FrictionWeight,val.ElasticityWeight)
			else
				return '\n<PhysicalProperties name="'..name..'">\n<CustomPhysics>false</CustomPhysics>\n</PhysicalProperties>'
			end
		end,
		["Faces"] = function(name,val)
			local faceInt = (val.Front and 32 or 0) + (val.Bottom and 16 or 0) + (val.Left and 8 or 0) + (val.Back and 4 or 0) + (val.Top and 2 or 0) + (val.Right and 1 or 0)
			return format('\n<Faces name="%s">\n<faces>%d</faces>\n</Faces>',name,faceInt)
		end,
		["Axes"] = function(name,val)
			local axisInt = (val.Z and 4 or 0) + (val.Y and 2 or 0) + (val.X and 1 or 0)
			return format('\n<Axes name="%s">\n<axes>%d</axes>\n</Faces>',name,axisInt)
		end,
		["Ray"] = function(name,val)
			local origin = val.Origin
			local direction = val.Direction
			return format('\n<Ray name="%s">\n<origin>\n<X>%.12f</X>\n<Y>%.12f</Y>\n<Z>%.12f</Z>\n</origin>\n<direction>\n<X>%.12f</X>\n<Y>%.12f</Y>\n<Z>%.12f</Z>\n</direction>\n</Ray>',name,origin.X,origin.Y,origin.Z,direction.X,direction.Y,direction.Z)
		end,
		["BinaryString"] = function(name,val)
			if val then
				return '\n<BinaryString name="'..name..'"><![CDATA['..val..']]></BinaryString>'
			else
				return ""
			end
		end,
		["ProtectedString"] = function(name,val)
			return '\n<ProtectedString name="'..name..'">'..gsub(val,xmlReplacePattern,xmlReplace)..'</ProtectedString>'
		end,
		["SharedString"] = function(name,val)
			return '\n<SharedString name="'..name..'">'..val..'</SharedString>'
		end,
	}
	
	local specialProps = {
		["TriangleMeshPart"] = {
			{Name = "LODData", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
			{Name = "PhysicalConfigData", ValueType = {Name = "SharedString"}, Special = "SharedString"},
		},
		["PartOperation"] = {
			{Name = "AssetId", ValueType = {Name = "Content"}, Special = "NotScriptable"},
			{Name = "InitialSize", ValueType = {Name = "Vector3"}, Special = "NotScriptable"},
			{Name = "ChildData", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
			{Name = "MeshData", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
			{Name = "PhysicsData", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
		},
		["MeshPart"] = {
			{Name = "InitialSize", ValueType = {Name = "Vector3"}, Special = "NotScriptable"},
			{Name = "PhysicsData", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
		},
		["Terrain"] = {
			{Name = "Decoration", ValueType = {Name = "bool"}, Special = "NotScriptable"},
			{Name = "MaterialColors", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
			{Name = "SmoothGrid", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
		},
		["TerrainRegion"] = {
			{Name = "SmoothGrid", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
		},
		["BinaryStringValue"] = {
			{Name = "Value", ValueType = {Name = "BinaryString"}, Special = "BinaryString"},
		},
		["Workspace"] = {
			{Name = "PGSPhysicsSolverEnabled", ValueType = {Name = "bool"}, Special = "Func", Func = function(obj) return obj:PGSIsEnabled() end},
			{Name = "CollisionGroups", ValueType = {Name = "string"}, Special = "Func", Func = function(obj)
				local groupTable = {}
				for i,v in pairs(game:GetService("PhysicsService"):GetCollisionGroups()) do
					groupTable[i] = v.name.."^"..v.id.."^"..v.mask
				end
				return table.concat(groupTable,"\\")
			end}
		},
		["Humanoid"] = {
			{Name = "Health_XML", ValueType = {Name = "float"}, Special = "IndexName", IndexName = "Health"},
		},
		["Sound"] = {
			{Name = "xmlRead_MaxDistance_3", ValueType = {Name = "float"}, Special = "IndexName", IndexName = "MaxDistance"},
		},
		["WeldConstraint"] = {
			{Name = "CFrame0", ValueType = {Name = "CFrame"}, Special = "NotScriptable"},
			{Name = "CFrame1", ValueType = {Name = "CFrame"}, Special = "NotScriptable"},
			{Name = "Part0Internal", ValueType = {Name = "Instance"}, Special = "IndexName", IndexName = "Part0"},
			{Name = "Part1Internal", ValueType = {Name = "Instance"}, Special = "IndexName", IndexName = "Part1"}
		},
		["Lighting"] = {
			{Name = "Technology", ValueType = {Category = "Enum"}, Special = "NotScriptable"}
		},
		["LocalizationTable"] = {
			{Name = "Contents", ValueType = {Name = "string"}, Special = "NotScriptable"}
		},
		["LocalScript"] = {
			{Name = "Source", ValueType = {Name = "ProtectedString"}, Special = "Decompile"}
		},
		["ModuleScript"] = {
			{Name = "Source", ValueType = {Name = "ProtectedString"}, Special = "Decompile"}
		}
	}

	local function getSaveProps(obj,class)
		local result = {}
		local count = 1

		local curClass = API.Classes[class]
		while curClass do
			local curClassName = curClass.Name
			local cacheProps = saveProps[curClassName]
			if cacheProps then
				table.move(cacheProps,1,#cacheProps,#result+1,result)
				break
			end

			local props = curClass.Properties
			for i = 1,#props do
				local prop = props[i]
				local propName = prop.Name
				if (prop.Serialization.CanSave and not prop.Tags.NotScriptable) or (propBypass[curClassName] and propBypass[curClassName][propName]) then
					if not propFilter[curClassName] or not propFilter[curClassName][propName] then
						local s,e = pcall(function() return obj[propName] end)
						if s then result[count] = prop count = count + 1 end
					end
				end
			end
			
			local specialProps = specialProps[curClassName]
			if specialProps then
				table.move(specialProps,1,#specialProps,#result+1,result)
				count = #result+1
			end

			curClass = curClass.Superclass
		end

		table.sort(result,function(a,b) return a.Name < b.Name end)
		return result
	end

	local function getTestInst(class)
		local s,inst = pcall(Instance.new,class)
		if not s then return {} end

		local defaultProps = {}

		local props = saveProps[class]
		for i = 1,#props do
			local prop = props[i]
			if not prop.Special then
				local propName = prop.Name
				defaultProps[propName] = inst[propName]
			end
		end

		return defaultProps
	end
	
	local function doDecompile(scr,saveSettings)
		local thread = coroutine.running()
		local finished = false
		
		if elysianexecute then
			local s,e = decompile(scr,function(src,err)
			if not finished then
				finished = true
				coroutine.resume(thread,src,err)
			end
			end,saveSettings.DecompileTimeout)
			
			if not s then return nil, e end
		else
			return decompile(scr,nil,saveSettings.DecompileTimeout)
		end
		
		-- extra measures because windows sucks
		spawn(function()
			wait(saveSettings.DecompileTimeout + 1) 
			if not finished then
				finished = true
				coroutine.resume(thread, nil, "decompile failed: decompiler timed out")
			end
		end)
		
		return coroutine.yield()
	end
	
	local function createStatusText()
		local statusText
		if syn or elysianexecute then
			statusText = Drawing.new("Text")
			statusText.Color = Color3.new(1,1,1)
			statusText.Outline = true
			statusText.OutlineColor = Color3.new(0,0,0)
			statusText[syn and "Size" or "FontSize"] = 50
			if syn then statusText.Visible = true end
		else
			return nil
		end
		
		local function updateStatus(text)
			local viewport = workspace.CurrentCamera.ViewportSize
			statusText.Text = text or ""
			statusText.Position = Vector2.new(viewport.X / 2 - statusText.TextBounds.X / 2, 50)
		end
		
		local function removeStatus()
			statusText:Remove()
		end
		
		return {Update = updateStatus, Remove = removeStatus}
	end
	
	local function predecompile(root,statusText,saveSettings)
		if not saveSettings.Decompile then return nil end
		
		local scripts,sources,checked = {},{},{}
		local ignoredServices
		local scriptCount,totalScripts = 1,0
		
		if root == game and saveSettings.DecompileIgnore then
			ignoredServices = {}
			for i,v in pairs(saveSettings.DecompileIgnore) do
				ignoredServices[i] = game:GetService(v)
			end
		end
		
		local isTable = type(root) == "table"
		local objs = isTable and root or {root}
		local maxThreads = saveSettings.MaxThreads or 3
		local isDescendantOf = game.IsDescendantOf
		
		if saveSettings.NilInstances and root == game and getnilinstances then
			local nilInsts = getnilinstances()
			table.move(nilInsts,1,#nilInsts,#objs+1,objs)
		end
		
		for i = 1,#objs do
			local nextRoot = objs[i]
			local descs = nextRoot:GetDescendants()
			descs[0] = nextRoot
			for i = 0,#descs do
				local obj = descs[i]
				if (isa(obj,"LocalScript") or isa(obj,"ModuleScript")) and not checked[obj] then
					local ignored = false
					if ignoredServices then
						for i = 1,#ignoredServices do
							if isDescendantOf(obj,ignoredServices[i]) then
								ignored = true
								break
							end
						end
					end
					
					if not ignored then
						scripts[scriptCount] = obj
						scriptCount = scriptCount + 1
					end
					
					checked[obj] = true
				end
			end
		end
		totalScripts = scriptCount - 1
		
		local left = totalScripts
		for i = 1,maxThreads do
			spawn(function()
				while #scripts > 0 do
					local nextScript = table.remove(scripts)
					local source, err = doDecompile(nextScript,saveSettings)
					
					if source then
						sources[nextScript] = source
					else
						sources[nextScript] = "-- This script could not be decompiled because:\n-- "..(err or "N/A")
					end
					
					left = left - 1
					if statusText then
						statusText.Update("Decompiling scripts... (" .. (totalScripts - left) .. "/" .. totalScripts .. ")")
					end
				end
			end)
		end
		
		while left > 0 do wait() end
		
		return sources
	end

	Serializer.SaveInstance = function(root,filename,opts)
		if not gameId then gameId = game.GameId end
		local saveSettings = {}
		for set,val in pairs(Settings.Serializer) do
			if opts and opts[set] ~= nil then
				saveSettings[set] = opts[set]
			else
				saveSettings[set] = val
			end
		end
		if saveSettings.DecompileMode and saveSettings.DecompileMode > 0 then saveSettings.Decompile = true end

		local isGame = root == game
		local isTable = type(root) == "table"
		if isTable and not root[1] then error("Empty Table") end
		
		if not filename then
			filename = isGame and "Place_"..game.PlaceId or "Place_"..game.PlaceId.."_Inst_"..(isTable and root[1] or root):GetDebugId()
		end
		if isGame then
			filename = filename:match("%.rbxlx?$") and filename or filename..".rbxlx"
		else	
			filename = filename:match("%.rbxmx?$") and filename or filename..".rbxmx"
		end
		env.writefile(filename,"")

		local startB = tick()
		local folderClasses = {["Player"] = true, ["PlayerScripts"] = true, ["PlayerGui"] = true, ["ScriptDebugger"] = true, ["Breakpoints"] = true, ["DebuggerWatch"] = true}
		local insts = {}
		local refs = {}
		local refCount = 1
		local depths = {}
		local filter = {}
		local hashs = {}
		local sharedStrings = {}
		local savingDefaultProps = not saveSettings.IgnoreDefaultProps
		local statusText = saveSettings.ShowStatus and createStatusText()
		local sources = predecompile(root,statusText,saveSettings)
		
		-- Set up filter
		if isGame then
			for i,v in pairs(service.Players:GetPlayers()) do
				if not saveSettings.SavePlayers then
					filter[v] = true
				end
				
				if saveSettings.RemovePlayerCharacters and v.Character then
					filter[v.Character] = true
				end
			end
		end
		
		if saveSettings.IsolateStarterPlayer then
			folderClasses["StarterPlayer"] = true
			folderClasses["StarterCharacterScripts"] = true
			folderClasses["StarterPlayerScripts"] = true
		end

		local buffer = {'<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n<Meta name="ExplicitAutoJoints">true</Meta>\n<External>null</External>\n<External>nil</External>'}
		local bufferCount = 2
		
		local function recur(obj)
			if filter[obj] then return end
			
			local class = oldIndex and oldIndex(obj,"ClassName") or obj.ClassName
			if folderClasses[class] then
				class = "Folder"
				if not saveProps["Folder"] then saveProps["Folder"] = getSaveProps(Instance.new("Folder"),"Folder") end
			end
			
			local ref = refs[obj]
			if not ref then ref = refCount refs[obj] = ref refCount = refCount + 1 end
			
			local props = saveProps[class]
			if not props then props = getSaveProps(obj,class) saveProps[class] = props end
			
			local testInst = testInsts[class]
			if not testInst then testInst = (not savingDefaultProps and getTestInst(class) or {}) testInsts[class] = testInst end
			
			buffer[bufferCount] = format('\n<Item class="%s" referent="RBX%d">\n<Properties>',class,ref)
			bufferCount = bufferCount + 1
			
			for i = 1,#props do
				local prop = props[i]
				local propName = prop.Name
				local propVal
				
				local special = prop.Special
				if special then
					if special == "NotScriptable" then
						propVal = getnspval and getnspval(obj,propName)
					elseif special == "BinaryString" then
						propVal = getbspval and getbspval(obj,propName,true)
					elseif special == "SharedString" and getpcd then
						local rawHash,content = getpcd(obj)
						if rawHash and content and #rawHash > 0 and #content > 0 then
							local hash = hashs[rawHash]
							if not hash then hash = encodeBase64(rawHash) hashs[rawHash] = hash end
							
							if not sharedStrings[hash] then
								sharedStrings[hash] = encodeBase64(content)
							end
							propVal = hash
						end
					elseif special == "IndexName" then
						propVal = oldIndex and oldIndex(obj,prop.IndexName) or obj[prop.IndexName]
					elseif special == "Func" then
						propVal = prop.Func(obj)
					elseif special == "Decompile" then
						if sources then
							propVal = sources[obj] or "-- Script failed to decompile or ignored"
						else
							propVal = "-- Decompiling is disabled"
						end
					end
				else
					propVal = oldIndex and oldIndex(obj,propName) or obj[propName]
				end
				
				if testInst[propName] ~= propVal or (savingDefaultProps and propVal ~= nil) then
					local typeData = prop.ValueType
					local propType = typeData.Name
					
					local convertFunc = valueConverters[propType]
					if convertFunc then
						buffer[bufferCount] = convertFunc(propName,propVal)
					elseif typeData.Category == "Enum" then
						buffer[bufferCount] = format('\n<token name="%s">%d</token>',propName,propVal.Value)
					elseif classes[propType] and propVal then
						local ref = refs[propVal]
						if not ref then ref = refCount refs[propVal] = ref refCount = refCount + 1 end
						buffer[bufferCount] = format('\n<Ref name="%s">RBX%d</Ref>',propName,ref)
					else
						buffer[bufferCount] = ""
					end
					bufferCount = bufferCount + 1
				end
			end
			
			buffer[bufferCount] = '\n</Properties>'
			bufferCount = bufferCount + 1
			
			if bufferCount > 10000 then
				env.appendfile(filename,table.concat(buffer))
				table.clear(buffer)
				bufferCount = 1
			end
			
			local ch = getChildren(obj)
			local szCh = #ch
			if szCh > 0 then
				for i = 1,szCh do
					recur(ch[i])
				end
			end
			
			buffer[bufferCount] = '\n</Item>'
			bufferCount = bufferCount + 1
		end
		
		if isGame then
			local gameCh = getChildren(root)
			for i = 1,#gameCh do
				local obj = gameCh[i]
				if not serviceBlacklist[obj.ClassName] then
					recur(obj)
				end
			end
			
			local message = [==[--[[
	Thank you for using Dex SaveInstance.
	You are recommended to save the game (if you used saveplace) right away to take advantage of the binary format.
	If your player cannot spawn into the game, please move the scripts in StarterPlayer elsewhere. (This is done by default)
	If the chat system does not work, please use the explorer and delete everything inside the Chat service. (Or run game:GetService("Chat"):ClearAllChildren())
	
	If union and meshpart collisions don't work, first run this script in the Studio command bar:
	local list = {}
	local coreGui = game:GetService("CoreGui")

	for i,v in pairs(game:GetDescendants()) do
		local s,e = pcall(function() return v:IsA("UnionOperation") or v:IsA("MeshPart") end)
		if s and e and not v:IsDescendantOf(coreGui) then
			list[#list+1] = v
		end
	end

	game.Selection:Set(list)
	
	After running it, go to the Properties window and change CollisionFidelity from "Box" to "Default".

	
	This file was generated with the following settings:
	
]==]
			
			for i, v in next, saveSettings do
				if type(v) == "table" then -- assume array
					local strings = {}
					for j, k in next, v do
						strings[#strings+1] = type(k) == "string" and ("\"" .. tostring(k) .. "\"") or tostring(v)
					end
					message = message .. "\t" .. tostring(i) .. " = { " .. table.concat(strings, ", ") .. " }\n"
				elseif i ~= "_Recurse" then
					message = message .. "\t" .. tostring(i) .. " = " .. tostring(v) .. "\n"
				end
				
			end
			
			message = message .. "]]"
			
			buffer[bufferCount] = [==[

<Item class="Script" referent="RBX999999999">
<Properties>
<string name="Name">README</string>
<ProtectedString name="Source">]==]..gsub(message, xmlReplacePattern, xmlReplace)..[==[</ProtectedString>
</Properties>
</Item>]==]
bufferCount = bufferCount + 1
		elseif isTable then
			for i = 1,#root do
				recur(root[i])
			end
		else
			recur(root)
		end
		
		-- Nil Instances
		if saveSettings.NilInstances and root == game and getnilinstances then
			local folderRef = refCount
			refCount = refCount + 1
			buffer[bufferCount] = '\n<Item class="Folder" referent="RBX'..folderRef..'">\n<Properties>\n<string name="Name">Nil Instances</string>\n</Properties>'
			bufferCount = bufferCount + 1
			
			local classes = API.Classes
			local nilInsts = getnilinstances()
			for i = 1,#nilInsts do
				local obj = nilInsts[i]
				local class = oldIndex and oldIndex(obj,"ClassName") or obj.ClassName
				if classes[class] and not classes[class].Tags.Service and not classes[class].Tags.NotCreatable and obj ~= game then
					local parentClass = nilClassParents[class]
					if parentClass then
						local parentRef = refCount
						refCount = refCount + 1
						buffer[bufferCount] = format('\n<Item class="%s" referent="RBX%d">\n<Properties>\n<string name="Name">%s Class</string>\n</Properties>',parentClass,parentRef,class)
						bufferCount = bufferCount + 1
						recur(obj)
						buffer[bufferCount] = "\n</Item>"
						bufferCount = bufferCount + 1
					else
						recur(obj)
					end
				end
			end
			buffer[bufferCount] = "\n</Item>"
			bufferCount = bufferCount + 1
		end
		
		-- SharedStrings
		buffer[bufferCount] = "\n<SharedStrings>"
		bufferCount = bufferCount + 1
		for hash,content in next,sharedStrings do
			buffer[bufferCount] = '\n<SharedString md5="'..hash..'">'..content..'</SharedString>'
			bufferCount = bufferCount + 1
		end
		
		buffer[bufferCount] = "\n</SharedStrings>\n</roblox>"
		env.appendfile(filename,table.concat(buffer))
		table.clear(buffer)
		table.clear(hashs)
		table.clear(sharedStrings)

		if statusText then
			statusText.Update("Saved to the file "..filename.." in "..(tick()-startB).." secs")
			delay(5,statusText.Remove)
		end
	end

	Serializer.Init = function(oldInd)
		oldIndex = oldInd

		gethiddenprop = env.gethiddenprop
		getnspval = env.getnspval or gethiddenprop
		getbspval = env.getbspval
		getnilinstances = env.getnilinstances
		getpcd = env.getpcd
		encodeBase64 = env.encodeBase64
		classes = API.Classes

		if syn then
			getbspval = function(obj,prop) return encodeBase64(gethiddenprop(obj,prop)) end
		end
	end

	return Serializer
end)()

Main = (function()
	local Main = {}
	
	Main.FetchAPI = function()
		local robloxVer = game:HttpGet("http://setup.roblox.com/versionQTStudio")
		local rawAPI = game:HttpGet("http://setup.roblox.com/"..robloxVer.."-API-Dump.json")
		local api = service.HttpService:JSONDecode(rawAPI)
		local classes,enums = {},{}

		for _,class in pairs(api.Classes) do
			local newClass = {}
			newClass.Name = class.Name
			newClass.Superclass = classes[class.Superclass]
			newClass.Properties = {}
			newClass.Functions = {}
			newClass.Events = {}
			newClass.Callbacks = {}
			newClass.Tags = {}

			if class.Tags then for c,tag in pairs(class.Tags) do newClass.Tags[tag] = true end end
			for __,member in pairs(class.Members) do
				local newMember = {}
				newMember.Name = member.Name
				newMember.Class = class.Name
				newMember.Tags ={}
				if member.Tags then for c,tag in pairs(member.Tags) do newMember.Tags[tag] = true end end

				local mType = member.MemberType
				if mType == "Property" then
					newMember.ValueType = member.ValueType
					newMember.Category = member.Category
					newMember.Serialization = member.Serialization
					table.insert(newClass.Properties,newMember)
				elseif mType == "Function" then
					newMember.Parameters = {}
					newMember.ReturnType = member.ReturnType.Name
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Functions,newMember)
				elseif mType == "Event" then
					newMember.Parameters = {}
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Events,newMember)
				end
			end

			classes[class.Name] = newClass
		end

		for _,enum in pairs(api.Enums) do
			local newEnum = {}
			newEnum.Name = enum.Name
			newEnum.Items = {}
			newEnum.Tags = {}

			if enum.Tags then for c,tag in pairs(enum.Tags) do newEnum.Tags[tag] = true end end
			for __,item in pairs(enum.Items) do
				local newItem = {}
				newItem.Name = item.Name
				newItem.Value = item.Value
				table.insert(newEnum.Items,newItem)
			end

			enums[enum.Name] = newEnum
		end

		local function getMember(class,member)
			if not classes[class] or not classes[class][member] then return end
			local result = {}

			local currentClass = classes[class]
			while currentClass do
				for _,entry in pairs(currentClass[member]) do
					result[#result+1] = entry
				end
				currentClass = currentClass.Superclass
			end

			table.sort(result,function(a,b) return a.Name < b.Name end)
			return result
		end

		return {
			Classes = classes,
			Enums = enums,
			GetMember = getMember
		}
	end

	Main.ResetSettings = function()
		local function recur(t)
			local res = {}
			for set,val in pairs(t) do
				if type(val) == "table" and val._Recurse then
					res[set] = recur(val)
				else
					res[set] = val
				end
			end
			return res
		end
		Settings = recur(DefaultSettings)
	end
	
	return Main
end)()

return {
	Init = function(oldindex)
		local api, e = Main.FetchAPI() -- TODO: only request new api on roblox updates?
		if not api then
			return nil, "FetchAPI failed (" .. tostring(e) .. ")"
		end
		API = api

		env = {}
		env.writefile = writefile
		env.appendfile = appendfile
		env.getnilinstances = getnilinstances or get_nil_instances
		env.gethiddenprop = gethiddenprop
		env.getnspval = getnspval
		env.getbspval = getbspval
		env.getpcd = getpcd or getpcdprop
		env.encodeBase64 = syn and syn.crypt.base64.encode or base64encode

		Main.ResetSettings()
		Serializer.Init(oldindex)

		return true
	end,

	Save = function(object, filename, options)
		return Serializer.SaveInstance(object, filename, options)
	end
}