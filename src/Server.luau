local module = {}

local repStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local proofOfWork = require(script.Parent.ProofOfWork)
local hashLib = require(script.Parent.HashLib)
local t = require(script.Parent.t)

if runService:IsClient() then return module end

local folderName = script.Parent.FolderName.Value

local folder = repStorage:FindFirstChild(folderName) :: Folder?
local reliableFolder = folder and folder:FindFirstChild("Reliable")
local unreliableFolder = folder and folder:FindFirstChild("Unreliable")
local functionFolder = folder and folder:FindFirstChild("Function")

local isAPlayer = t.instanceIsA("Player")

-- Each has a list of PoW results that we've already seen
local seenPowResults = {} :: {[Player]: { [string]: boolean }}

local DEFAULT_POW_DIFFICULTY = 1

local POW_STRING_LENGTH = 15
local POW_MAX_DIFFICULTY = 64

local SEED_SIZE_RANGE = NumberRange.new(16, 32)
local POSSIBLE_SEED_CHARS = {
	"a", "b", "c", "d", "e", "f", "g";
	"h", "i", "j", "k", "l", "m", "n";
	"o", "p", "q", "r", "s", "t", "u";
	"v", "w", "x", "y", "z";

	"1", "2", "3", "4", "5";
	"6", "7", "8", "9", "0";
	
	"!", "@", "#", "$", "%";
	"^", "&", "*", "(", ")";
}

local MIN_SEED_CHAR_IDX = 1
local MAX_SEED_CHAR_IDX = #POSSIBLE_SEED_CHARS

local POW_RESULT_KEYS = {
	iterations = "number";
	result = "string";
	hash = "string";
	time = "number";
	rate = "number";
}

local SECURITY_ATTRIBUTES = {
	Seed = "ProofOfWorkSeed";
	Difficulty = "ProofOfWorkDifficulty";
}

type RemoteCallbackFn = (player: Player, ...any) -> ...any
type BaseRemoteEvent = (RemoteEvent | UnreliableRemoteEvent)
type RemoteClassName = "RemoteEvent" | "UnreliableRemoteEvent" | "RemoteFunction"

if folder then
	warn(`Networking folder '{folderName}' already exists`)
else
	folder = Instance.new("Folder", repStorage)
	folder.Name = folderName

	reliableFolder = Instance.new("Folder", folder)
	unreliableFolder = Instance.new("Folder", folder)
	functionFolder = Instance.new("Folder", folder)

	reliableFolder.Name = "Reliable"
	unreliableFolder.Name = "Unreliable"
	functionFolder.Name = "Function"
end

local function generateRandomString(
	length: number
): string
	local chars = {}

	for i = 1, length do
		chars[i] = POSSIBLE_SEED_CHARS[math.random(MIN_SEED_CHAR_IDX, MAX_SEED_CHAR_IDX)]
	end

	return table.concat(chars)
end

local function getNumLeadingZeros(
	str: string
): number
	local count = 0
	
	for i = 1, #str do
		if str:sub(i, i) == "0" then
			count += 1
		else
			break
		end
	end
	
	return count
end

local function isPOWResultValid(
	player: Player,
	remote: BaseRemoteEvent,
	pow: proofOfWork.ProofOfWorkResult
): (boolean, string)
	if typeof(pow) ~= "table" then
		return false, `Result must be of type 'table', not '{type(pow)}'`
	end
	
	for idx, expectedType in POW_RESULT_KEYS do
		if expectedType ~= typeof(pow[idx]) then
			return false, `Result key '{idx}' must be of type '{expectedType}', not '{typeof(pow[idx])}'`
		end
	end
	
	for idx, value in pow do
		if POW_RESULT_KEYS[idx] == nil then
			return false, `Result key '{idx}' is an invalid key`
		end
	end
	
	local expectedLeadingZeros = remote:GetAttribute(SECURITY_ATTRIBUTES.Difficulty) or 1
	local leadingZeros = getNumLeadingZeros(pow.hash)
	
	if leadingZeros < expectedLeadingZeros then
		return false, `Result hash does not have enough leading zeros ({leadingZeros}/{expectedLeadingZeros}, insufficient difficulty level)`
	end
	
	local powLength = #pow.result
	
	if powLength > SEED_SIZE_RANGE.Max + POW_STRING_LENGTH or powLength < SEED_SIZE_RANGE.Min then
		return false, "Result string is too large or is too small"
	end
	
	local seed = remote:GetAttribute(SECURITY_ATTRIBUTES.Seed) or ""
	local hashed = hashLib.sha256(pow.result)
	
	if hashed ~= pow.hash then
		return false, `Client hash result does not match server hash result ({hashed} != {pow.hash})`
	end
	
	if not seenPowResults[player] then
		return false, "Player has no seen PoW results list"
	end
	
	if seenPowResults[player][pow.hash] then
		return false, `Result hash has already been sent by the player ({pow.hash})`
	end
	
	return true
end

local function onPlayerJoining(
	player: Player,
	joined: boolean
)
	-- If a player just joined, give them a new cache
	-- Otherwise remove their cache (so we don't have a memory leak)
	seenPowResults[player] = (joined == true and {}) or nil
end

local function onServerEvent(
	remote: BaseRemoteEvent,
	callback: RemoteCallbackFn,
	player: Player,
	pow: proofOfWork.ProofOfWorkResult,
	...: any
)	
	local valid, err = isPOWResultValid(player, remote, pow)
	
	if not valid then
		warn(`'{player.Name}' had a {remote.ClassName} Proof-of-Work result invalidated: {err}`)
		return
	end
	
	callback(player, ...)
end

local function onServerInvoke(
	remote: RemoteFunction,
	callback: RemoteCallbackFn,
	player: Player,
	pow: proofOfWork.ProofOfWorkResult,
	...: any
)
	local valid, err = isPOWResultValid(player, remote, pow)

	if not valid then
		warn(`'{player.Name}' had a {remote.ClassName} Proof-of-Work result invalidated: {err}`)
		return
	end
	
	return callback(player, ...)
end

local function setupRemoteEvent(
	remote: BaseRemoteEvent
): RBXScriptConnection
	local length = math.random(SEED_SIZE_RANGE.Min, SEED_SIZE_RANGE.Max)
	
	remote:SetAttribute(SECURITY_ATTRIBUTES.Seed, generateRandomString(length))
	remote:SetAttribute(SECURITY_ATTRIBUTES.Difficulty, DEFAULT_POW_DIFFICULTY)
end

local function connectCallbackTo(
	remote: BaseRemoteEvent,
	callback: RemoteCallbackFn
): RBXScriptConnection
	return remote.OnServerEvent:Connect(function(...)
		onServerEvent(remote, callback, ...)
	end)
end

local function getOrCreateRemote(
	event: string,
	remoteClassName: RemoteClassName
): BaseRemoteEvent
	local holder = (remoteClassName == "UnreliableRemoteEvent" and unreliableFolder) 
		or (remoteClassName == "RemoteFunction" and functionFolder)
		or reliableFolder
	
	local remote = holder:FindFirstChild(event)
	
	if remote then
		return remote
	end

	remote = Instance.new(remoteClassName, holder)
	setupRemoteEvent(remote)
	remote.Name = event

	return remote
end

local function fireToClients(
	event: string,
	remoteClassName: RemoteClassName,
	playerList: { Player }?,
	...: any
): boolean
	local remote = getOrCreateRemote(event, remoteClassName)
	
	if remote then
		if playerList then
			for _, player in playerList do
				remote:FireClient(player, ...)
			end
		else
			remote:FireAllClients(...)
		end
	end
end

local function getPlayersExcept(
	exceptions: {Player}
)
	local playerList = {}
	
	for _, player in players:GetPlayers() do
		if not table.find(exceptions, player) then
			table.insert(playerList, player)
		end
	end
	
	return playerList
end

------
-- Global
------

function module:SetDifficulty(
	event: string,
	difficulty: number,
	remoteClassName: RemoteClassName
)
	assert(t.string(event))
	assert(t.numberConstrained(difficulty, 1, POW_MAX_DIFFICULTY))
	assert(t.string(remoteClassName))
	
	local remote = getOrCreateRemote(event, remoteClassName)
	remote:SetAttribute(SECURITY_ATTRIBUTES.Difficulty, difficulty)
end

------
-- RemoteFunctions
------

--[[
	Sets the 'OnServerInvoke' property for the input RemoteFunction to the input callback
	Returns a function which can be called in order to disconnect the callback
	
	You can also just call this function with nil as the 2nd argument to disconnect the callback
	since RemoteFunctions can only be assigned one callback at a time
]]
function module:OnInvoke(
	event: string,
	callback: RemoteCallbackFn?
)
	assert(t.string(event))
	assert(t.callback(callback))
	
	local remote: RemoteFunction = getOrCreateRemote(event, "RemoteFunction")
	
	if callback then
		remote.OnServerInvoke = function(...)
			return onServerInvoke(remote, callback, ...)
		end
	else
		remote.OnServerInvoke = nil
	end
	
	return function()
		remote.OnServerInvoke = nil
	end
end

------
-- RemoteEvents
------

--[[
	Connects to 'OnServerEvent' for the input RemoteEvent
	Returns a function which can be called in order to disconnect the callback
]]
function module:On(
	event: string,
	callback: RemoteCallbackFn
): RBXScriptConnection
	assert(t.string(event))
	assert(t.callback(callback))
	
	local remote = getOrCreateRemote(event, "RemoteEvent")
	return connectCallbackTo(remote, callback)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for the input player
]]
function module:Fire(
	player: Player,
	event: string,
	...: any
)
	assert(isAPlayer(player))
	assert(t.string(event))
	
	fireToClients(event, "RemoteEvent", {player}, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for the input player list
]]
function module:FireToList(
	playerList: {Player},
	event: string,
	...: any
)
	assert(t.table(playerList))
	assert(t.string(event))
	
	for _, player in playerList do
		assert(isAPlayer(player))
	end
	
	fireToClients(event, "RemoteEvent", playerList, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for all players
]]
function module:FireToAll(
	event: string,
	...: any
)
	assert(t.string(event))
	
	fireToClients(event, "RemoteEvent", nil, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for all players except the input ones
]]
function module:FireToAllExcept(
	exceptions: {Player},
	event: string,
	...: any
)
	assert(t.table(exceptions))
	assert(t.string(event))

	for _, player in exceptions do
		assert(isAPlayer(player))
	end
	
	fireToClients(event, "RemoteEvent", getPlayersExcept(exceptions), ...)
end

------
-- UnreliableRemoteEvents
------

--[[
	Connects to 'OnServerEvent' for the input UnreliableRemoteEvent
	Returns a function which can be called in order to disconnect the callback
]]
function module:OnUnreliable(
	event: string,
	callback: RemoteCallbackFn
): RBXScriptConnection
	assert(t.string(event))
	assert(t.callback(callback))
	
	local remote = getOrCreateRemote(event, "UnreliableRemoteEvent")
	return connectCallbackTo(remote, callback)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for the input player
]]
function module:FireUnreliable(
	player: Player,
	event: string,
	...: any
)
	assert(isAPlayer(player))
	assert(t.string(event))
	
	fireToClients(event, "UnreliableRemoteEvent", {player}, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for the input player list
]]
function module:FireToListUnreliable(
	playerList: {Player},
	event: string,
	...: any
)
	assert(t.table(playerList))
	assert(t.string(event))
	
	for _, player in playerList do
		assert(isAPlayer(player))
	end
	
	fireToClients(event, "UnreliableRemoteEvent", playerList, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for all players
]]
function module:FireToAllUnreliable(
	event: string,
	...: any
)
	assert(t.string(event))
	
	fireToClients(event, "UnreliableRemoteEvent", nil, ...)
end

--[[
	Calls 'FireClient' for the input RemoteEvent (or UnreliableRemoteEvent) for all players except the input ones
]]
function module:FireToAllExceptUnreliable(
	exceptions: {Player},
	event: string,
	...: any
)
	assert(t.table(exceptions))
	assert(t.string(event))

	for _, player in exceptions do
		assert(isAPlayer(player))
	end
	
	fireToClients(event, "UnreliableRemoteEvent", getPlayersExcept(exceptions), ...)
end

------
-- Init
------

do -- Setup seen PoW result caches
	players.PlayerAdded:Connect(function(player)
		onPlayerJoining(player, true)
	end)

	players.PlayerRemoving:Connect(function(player)
		onPlayerJoining(player, false)
	end)

	for _, player in players:GetPlayers() do
		task.spawn(onPlayerJoining, player)
	end
end

return module
