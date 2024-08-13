#!lua name=my_lib

-- MurmurHash3 implementation in Lua
local function murmurhash3_32(key, seed)
    local c1 = 0xcc9e2d51
    local c2 = 0x1b873593
    local r1 = 15
    local r2 = 13
    local m = 5
    local n = 0xe6546b64

    local hash = seed

    local len = #key
    local roundedEnd = bit.band(len, 0xfffffffc) -- round down to 4 byte block

    for i = 1, roundedEnd, 4 do
        local k = bit.bor(
            string.byte(key, i),
            bit.lshift(string.byte(key, i + 1), 8),
            bit.lshift(string.byte(key, i + 2), 16),
            bit.lshift(string.byte(key, i + 3), 24)
        )
        k = k * c1
        k = bit.bor(bit.lshift(k, r1), bit.rshift(k, 32 - r1))
        k = k * c2

        hash = bit.bxor(hash, k)
        hash = bit.bor(bit.lshift(hash, r2), bit.rshift(hash, 32 - r2))
        hash = hash * m + n
    end

    local k = 0
    if bit.band(len, 0x03) == 3 then
        k = bit.lshift(string.byte(key, roundedEnd + 2), 16)
    end
    if bit.band(len, 0x03) >= 2 then
        k = bit.bor(k, bit.lshift(string.byte(key, roundedEnd + 1), 8))
    end
    if bit.band(len, 0x03) >= 1 then
        k = bit.bor(k, string.byte(key, roundedEnd))
        k = k * c1
        k = bit.bor(bit.lshift(k, r1), bit.rshift(k, 32 - r1))
        k = k * c2
        hash = bit.bxor(hash, k)
    end

    hash = bit.bxor(hash, len)

    hash = bit.bxor(hash, bit.rshift(hash, 16))
    hash = hash * 0x85ebca6b
    hash = bit.bxor(hash, bit.rshift(hash, 13))
    hash = hash * 0xc2b2ae35
    hash = bit.bxor(hash, bit.rshift(hash, 16))

    return hash
end

-- Mersenne Twister implementation in Lua
local function init(rng, seed)
    rng.mt[0] = seed
    for i = 1, 623 do
        rng.mt[i] = bit.band((1812433253 * bit.bxor(rng.mt[i - 1], bit.rshift(rng.mt[i - 1], 30)) + i), 0xffffffff)
    end
    rng.index = 624
end

local function twist(rng)
    for i = 0, 623 do
        local y = bit.bor(bit.band(rng.mt[i], 0x80000000), bit.band(rng.mt[(i + 1) % 624], 0x7fffffff))
        rng.mt[i] = bit.bxor(rng.mt[(i + 397) % 624], bit.rshift(y, 1))
        if y % 2 ~= 0 then
            rng.mt[i] = bit.bxor(rng.mt[i], 0x9908b0df)
        end
    end
    rng.index = 0
end

local function extract_number(rng)
    if rng.index >= 624 then
        twist(rng)
    end

    local y = rng.mt[rng.index]
    y = bit.bxor(y, bit.rshift(y, 11))
    y = bit.bxor(y, bit.band(bit.lshift(y, 7), 0x9d2c5680))
    y = bit.bxor(y, bit.band(bit.lshift(y, 15), 0xefc60000))
    y = bit.bxor(y, bit.rshift(y, 18))

    rng.index = rng.index + 1
    return bit.band(y, 0xffffffff)
end

local function get_random_number(seed)
    local rng = { mt = {}, index = 0 }
    init(rng, seed)
    return extract_number(rng)
end
-- End of Mersenne Twister implementation

-- Util functions
-- ============================================================================
-- Internal function used to convert array of integers into Redis byte array
--
local function to_byte_array(json_str)    
    -- Initialize an empty table to hold the byte array
    local byte_array = {}    
    -- Convert each integer to an 8-byte representation and add to the byte array
    for _, num in ipairs(vector) do
        local byte_str = string.pack("I8", num)
        table.insert(byte_array, byte_str)
    end    
    
    -- Concatenate all the 8-byte strings into a single byte array
    local concatenated_bytes = table.concat(byte_array)
    
    -- Convert the byte array to a hexadecimal string
    local hex_str = {}
    for i = 1, #concatenated_bytes do
        table.insert(hex_str, string.format("%02X", string.byte(concatenated_bytes, i)))
    end
    
    return table.concat(hex_str)
end


local function count_trailing_zeros(num)
    local count = 0
    while num > 0 and bit.band(num, 1) == 0 do
        count = count + 1
        num = bit.rshift(num, 1)
    end
    return count
end

local function redis_rnd(token, p)
    local hash = murmurhash3_32(token, 0) -- crc32.hash(token)
    local random_number = get_random_number(hash)

    -- Convert the random number to a 64-bit representation
    local random_number_64 = bit.tobit(random_number)

    -- Extract the first p bits from the 64-bit representation
    local mask = bit.lshift(1, p) - 1
    local first_p_bits = bit.band(random_number_64, mask)

    -- Count the number of trailing zeros in the 64-bit representation
    local trailing_zeros = count_trailing_zeros(random_number_64)

    return random_number, first_p_bits, trailing_zeros
end

-- Function to get a specified number of random keys
local function random_keys(num_keys)
    local random_keys = {}
    for i = 1, num_keys do
        local key = redis.call("RANDOMKEY")
        if key then
            table.insert(random_keys, key)
        end
    end
    return random_keys
end

-- End of Util function

-- Exported Functions
-- =============================================================================

-- Function updates '_last_modified_' field on each update of the hash
--
local function my_hset(keys, args)
    local hash = keys[1]
    local time = redis.call('TIME')[1]
    return redis.call('HSET', hash, '_last_modified_', time, unpack(args))
end

-- Function callable from outside Redis
--
local function redis_rand(keys, args)
    local token = args[1]
    local p = args[2]

    local random_number, first_p_bits, trailing_zeros = redis_rnd(token, p)

    -- Create a table with the return values
    local result = {
        random_number = random_number,
        first_p_bits = first_p_bits,
        trailing_zeros = trailing_zeros
    }

    -- Encode the table into a JSON string
    local json_result = cjson.encode(result)

    return json_result
end

-- Ingest only tokens creating token's hashes for each token;
-- keys = [token_key, entity_key]
-- args[1] is a precission of HllSet (number of leading bits used to number bins)
-- the reast of
-- args ia array of tokens to be processed
--
-- Fieldes token and refs are presented as sets
--
local function ingest_01(keys, args)
    local key1  = keys[1] -- prefix for token hash
    local key2  = keys[2] -- hash key for the Entity instance or graph node (they should be the same)
    local p     = tonumber(args[1])
    local batch = tonumber(args[2])
    local tokens = cjson.decode(args[3])

    local pipeline = {}
    local pipeline_size = 0

    for i = 1, #tokens do
        local token = tokens[i]
        local random_number, first_p_bits, trailing_zeros = redis_rnd(token, p)

        local token_hash = {
            id = random_number,
            token = token,
            bin = first_p_bits,
            zeros = trailing_zeros,
            refs = key2
        }

        local redis_key = key1 .. ":" .. token
        table.insert(pipeline, {"HMSET", redis_key, "id", token_hash.id, "bin", token_hash.bin, "zeros", token_hash.zeros})
        table.insert(pipeline, {"SADD", redis_key .. ":tokens", token_hash.token})
        table.insert(pipeline, {"SADD", redis_key .. ":refs", token_hash.refs})
        pipeline_size = pipeline_size + 3

        if pipeline_size >= batch then
            redis.call("MULTI")
            for _, cmd in ipairs(pipeline) do
                redis.call(unpack(cmd))
            end
            redis.call("EXEC")
            pipeline = {}
            pipeline_size = 0
        end
    end

    -- Execute any remaining commands in the pipeline
    if pipeline_size > 0 then
        redis.call("MULTI")
        for _, cmd in ipairs(pipeline) do
            redis.call(unpack(cmd))
        end
        redis.call("EXEC")
    end
end

-- Performs bitwise operations on encoded as JSON strings vectors of integers
-- 
local function bit_ops(keys, args)
    local vector1 = cjson.decode(args[1])
    local vector2 = cjson.decode(args[2])
    local operation = args[3]

    local num_args = #args
    if num_args == 3 then
        redis.error_reply("Wrong number of arguments. Expected 3 arguments.")
    end

    local size_vector1 = #vector1
    local size_vector2 = #vector2

    if size_vector1 ~= size_vector2 then
        redis.error_reply("Vectors provided in args[1] and args[2] must be of the same size.")
    end

    local result = {}

    if operation == "AND" then
        for i = 1, #vector1 do
            table.insert(result, bit.band(vector1[i], vector2[i]))
        end
    elseif operation == "OR" then
        for i = 1, #vector1 do
            table.insert(result, bit.bor(vector1[i], vector2[i]))
        end
    elseif operation == "XOR" then
        for i = 1, #vector1 do
            table.insert(result, bit.bxor(vector1[i], vector2[i]))
        end
    else
        return redis.error_reply("Unsupported operation")
    end

    return cjson.encode(result)
end

redis.register_function('my_hset', my_hset)
redis.register_function('bit_ops', bit_ops)
redis.register_function('redis_rand', redis_rand)
redis.register_function('ingest_01', ingest_01)