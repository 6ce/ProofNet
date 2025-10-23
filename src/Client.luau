local module = {}

local repStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local localPlayer = players.LocalPlayer

local proofOfWork = require(script.Parent.ProofOfWork)
local t = require(script.Parent.t)

if runService:IsServer() then return module end

-- These are destroyed purely for the inability for exploiters to read them
-- Atleast until they use getnilinstances...
script.Parent.Server:Destroy()
script.Parent.HashLib:Destroy()
script.Parent.ProofOfWork:Destroy()

local folderName = script.Parent.FolderName.Value

local folder = repStorage:WaitForChild(folderName, 10) :: Folder?
local reliableFolder = folder and folder:WaitForChild("Reliable")
local unreliableFolder = folder and folder:WaitForChild("Unreliable")
local functionFolder = folder and folder:WaitForChild("Function")

if not folder then error(`Networking folder '{folderName}' not found in ReplicatedStorage`) end

local SECURITY_ATTRIBUTES = {
	Seed = "ProofOfWorkSeed";
	Difficulty = "ProofOfWorkDifficulty";
}

type RemoteCallbackFn = (...any) -> ()
type RemoteClassName = "RemoteEvent" | "UnreliableRemoteEvent"
type BaseRemoteEvent = (RemoteEvent | UnreliableRemoteEvent)

--[[
	Connects to OnClientEvent for the given RemoteEvent (or UnreliableRemoteEvent)
]]
local function connectToOnClientEvent(
	event: string,
	callback: RemoteCallbackFn,
	remoteClassName: RemoteClassName
): RBXScriptConnection?
	local holder = (remoteClassName == "UnreliableRemoteEvent" and unreliableFolder) or reliableFolder
	local remote = holder:FindFirstChild(event)
	
	if remote then
		return remote.OnClientEvent:Connect(callback)
	end
end

--[[
	Calls FireServer for the given RemoteEvent (or UnreliableRemoteEvent)
]]
local function fireServerOn(
	event: string,
	remoteClassName: RemoteClassName,
	...: any
): boolean
	local holder = (remoteClassName == "UnreliableRemoteEvent" and unreliableFolder) or reliableFolder
	local remote = holder:FindFirstChild(event)
	
	if remote then
		local seed = remote:GetAttribute(SECURITY_ATTRIBUTES.Seed) or ""
		local difficulty = remote:GetAttribute(SECURITY_ATTRIBUTES.Difficulty) or 1
		local pow = proofOfWork(seed, difficulty)
		
		if pow then
			remote:FireServer(pow, ...)
			return true
		end
	end
	
	return false
end

--[[
	Calls 'InvokeServer' for the input RemoteFunction
]]
function module:Invoke(
	event: string,
	...: any
): any
	assert(t.string(event))
	
	local remote = functionFolder:FindFirstChild(event) :: RemoteFunction
	
	if remote then
		local seed = remote:GetAttribute(SECURITY_ATTRIBUTES.Seed) or ""
		local difficulty = remote:GetAttribute(SECURITY_ATTRIBUTES.Difficulty) or 1
		local pow = proofOfWork(seed, difficulty)
		return remote:InvokeServer(pow, ...)
	end
end

--[[
	Listens to 'OnClientEvent' for the input RemoteEvent
]]
function module:On(
	event: string,
	callback: RemoteCallbackFn
): RBXScriptConnection?
	assert(t.string(event))
	assert(t.callback(callback))
	
	return connectToOnClientEvent(event, callback, "RemoteEvent")
end

--[[
	Listens to 'OnClientEvent' for the input UnreliableRemoteEvent
]]
function module:OnUnreliable(
	event: string,
	callback: RemoteCallbackFn
): RBXScriptConnection
	assert(t.string(event))
	assert(t.callback(callback))
	
	return connectToOnClientEvent(event, callback, "UnreliableRemoteEvent")
end

--[[
	Calls 'FireServer' for the input RemoteEvent
]]
function module:Fire(
	event: string,
	...: any
): boolean
	assert(t.string(event))
	
	return fireServerOn(event, "RemoteEvent", ...)
end

--[[
	Calls 'FireServer' for the input UnreliableRemoteEvent
]]
function module:FireUnreliable(
	event: string,
	...: any
): boolean
	assert(t.string(event))
	
	return fireServerOn(event, "UnreliableRemoteEvent", ...)
end

return module
