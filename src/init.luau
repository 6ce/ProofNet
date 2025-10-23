local runService = game:GetService("RunService")

local server = require(script.Server)
local client = require(script.Client)

export type Client = typeof(client)
export type Server = typeof(server)

return {
	Client = client;
	Server = server; 
}
