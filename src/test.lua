-- local bit = require('bit32')
-- local crc32 = require('crc32')

local function count_trailing_zeros(num)
    local count = 0
    while num > 0 and bit.band(num, 1) == 0 do
        count = count + 1
        num = bit.rshift(num, 1)
    end
    return count
end

local function redis_rnd(token, p)
    local hash = crc32.hash(token)
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

-- Example usage:
local token = "example_token"
local p = 8
local random_number, first_p_bits, trailing_zeros = redis_rnd(token, p)
print(random_number, first_p_bits, trailing_zeros)