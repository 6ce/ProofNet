--!native

local DEFAULT_TIMEOUT = 10
local STEP_WAIT_INCREMENT = 1000

local STRING_LENGTH = 15
local POSSIBLE_CHARS = {
	"a", "b", "c", "d", "e", "f", "g";
	"h", "i", "j", "k", "l", "m", "n";
	"o", "p", "q", "r", "s", "t", "u";
	"v", "w", "x", "y", "z";
	
	"1", "2", "3", "4", "5";
	"6", "7", "8", "9", "0";
}

local MIN_CHAR_IDX = 1
local MAX_CHAR_IDX = #POSSIBLE_CHARS

local seenResults = {} :: { [string]: boolean }

local hashLib = require(script.Parent.HashLib)

export type ProofOfWorkResult = {
	iterations: number;
	result: string;
	hash: string;
	time: number;
	rate: number;
}

local function generateRandomString(
	length: number
): string
	local chars = table.create(length)
	
	for i = 1, length do
		chars[i] = POSSIBLE_CHARS[math.random(MIN_CHAR_IDX, MAX_CHAR_IDX)]
	end
	
	return table.concat(chars)
end

local function isSolved(
	hashed: string,
	leadingZeros: number
): boolean
	return hashed:sub(1, leadingZeros) == ("0"):rep(leadingZeros)
end

local function proofOfWorkSolver(
	seed: string,
	leadingZeros: number,
	timeout: number?
): ProofOfWorkResult?
	timeout = timeout or DEFAULT_TIMEOUT
	
	local startTime = os.clock()
	local iterations = 0
	
	while true do
		local rand = generateRandomString(STRING_LENGTH)
		local str = seed .. rand
		local hashed = hashLib.sha256(str)
		
		local elapsed = os.clock() - startTime
		
		if elapsed > timeout then
			break
		end
		
		iterations += 1
		
		if iterations % STEP_WAIT_INCREMENT == 0 then
			task.wait()
		end
		
		if isSolved(hashed, leadingZeros) and not seenResults[hashed] then
			seenResults[hashed] = true
			
			return {
				iterations = iterations;
				result = str;
				hash = hashed;
				time = elapsed;
				rate = iterations / elapsed;
			}
		end
	end
end

return proofOfWorkSolver
