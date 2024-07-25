include("sets.jl")
include("utils.jl")

module Tokens
    using ..HllSets
    using ..Util

    using Redis
    using JSON3: JSON3
    using EasyConfig
    using DataFrames: DataFrame
    using DataFrames: DataFrameRow


    #---------------------------------------------------------------------------- Token #
    struct Token 
        id::Int
        bin::Int
        zeros::Int
        token::Set{String}
        tf::Int
    end

    Token(id::Int, bin::Int, zeros::Int; token::Set{String}, tf::Int) = Token(id, bin, zeros, JSON3.read(token), tf)
    Token(row::DataFrameRow) = Token(row.id, row.bin, row.zeros, JSON3.read(row.token), row.tf)
    Token(dict::Dict{Symbol, Any}) = Token(dict.id, dict.bin, dict.zeros, JSON3.read(dict.token), dict.tf)

    function Token(dict::Dict{AbstractString, AbstractString})
        id = parse(Int, dict["id"])
        bin = parse(Int, dict["bin"])
        zeros = parse(Int, dict["zeros"])
        token = JSON3.read(dict["token"], Set{String})
        tf = parse(Int, dict["tf"])
        return Token(id, bin, zeros, token, tf)
    end

    function Base.show(io::IO, o::Token)
        print(io, "Token($(o.id), $(o.bin), $(o.zeros), $(o.token), $(o.tf))")
    end

    args(t::Token) = (t.id, t.bin, t.zeros, JSON3.write(collect(t.token)), t.tf)
    dict(t::Token) = Dict(:id => t.id, :bin => t.bin, :zeros => t.zeros, :token => JSON3.write(t.token), :tf => t.tf)

    # Tokens operations
    #-----------------------------------------------------------------------------# 
    """
        set_token(conn::RedisConnection, token::Token, node_sha1::String, status::String)

        Store a `Token` object in a Redis database using a `RedisConnection`. 
        In Redis a `Token` is stored as a hash with the following fields:
            - id: The `Token`'s id.
            - bin: The `Token`'s bin.
            - token: The `Token`'s token.
            - zeros: The `Token`'s zeros.
            - tf: The `Token`'s term frequency.
            - search: The generated field in hash that holds a vector for RediSearch.
        This also manages the Redis set and HyperLogLog (HLL) set associated with the `Token`.
        Redis set holds all the SHA1 hashes of the nodes that contain the `Token`.
        HllSet set of token references is used to generate 'search' vector field for the RediSearch. 

        This function performs several operations:
        - Adds the `node_sha1` to a Redis set identified by the `Token`'s `id`.
        - Creates a HyperLogLog (HLL) set and adds token references from the Redis set.
        - Updates the `Token` object's dictionary representation with a new field `search`, which contains 
            a blob of the HLL set dump.
        - Constructs a Redis hash key using the `status`, `Token` object, and `Token`'s `id`.
        - Stores the updated `Token` dictionary in Redis under the constructed key.

        # Arguments
        - `conn::RedisConnection`: The connection to the Redis server.
        - `token::Token`: The `Token` object to be stored.
        - `node_sha1::String`: A SHA1 hash to be added to the Redis set associated with the `Token`.
        - `status::String`: A string indicating the status, used as part of the key under which the `Token` is stored in Redis.

        # Examples
        ```
            julia
            conn = RedisConnection("localhost", 6379)
            token = Token(1, 2, 3, Set(["example"]), 5)
            set_token(conn, token, "sha1example", "b")
        ```
        This function is part of the `Tokens` module and is designed for managing `Token` objects within a Redis database, 
        leveraging Redis sets and HyperLogLog for efficient storage and retrieval.
    """   
    function set_token(conn::RedisConnection, token::Token, node_sha1::String, status::String)
        # Add node_sha1 to Redis set that holds all node's refs for this token
        size_before = Redis.scard(conn, token.id)
        Redis.sadd(conn, token.id, node_sha1)
        size_after = Redis.scard(conn, token.id)
        # If size_after is greater than size_before, then update token hash in Redis
        # with new term frequency and search field
        if size_after > size_before
            token_dict = dict(token)
            token_dict[:tf] = token.tf + 1
            # Update token_dict with new field 'search'
            # First create tiny hll set and add token refs from Redis set 
            hll = HllSets.HllSet{8}()
            HllSets.add!(hll, Redis.smembers(conn, token.id))
            # Add search field to token_dict
            token_dict[:searchable] = Util.to_blob(HllSets.dump(hll))
            # Submit token to redis
            key_name = string(status, ":", "token", ":", token.id)
            Redis.hmset(conn, key_name, token_dict)
        end
    end

    function set_tokens(conn::RedisConnection, tokens::Set{String}, node_sha1::String, status::String; P::Int=10, seed::Int=0)
        for token in tokens
            tf = 0
            _token = Set{String}()

            x = HllSets.u_hash(token, seed=seed)
            bin = HllSets.getbin(x, P=P)
            zeros = HllSets.getzeros(x, P=P)
            key_name = string(status, ":", "token", ":", x)

            # Assuming tf is retrieved from Redis and is a string
            hash = Redis.hgetall(conn, key_name)            

            # Check if tf_str is not nothing and then convert it to an integer
            if !(hash == nothing || isempty(hash))
                tf = parse(Int, hash["tf"])                
                _token = JSON3.read(hash["token"], Set{String})
            else
                tf = 0
            end            
            
            push!(_token, token)
            
            token = Token(x, bin, zeros, _token, tf)
            set_token(conn, token, node_sha1, status)
        end
    end

    function get_token(conn::RedisConnection, token_id::Int, status::String)
        key_name = status * ":" * "token" * ":" * token.id
        token_dict = Redis.hgetall(conn, key_name)
        token = Token(token_dict)
        return token
    end

    function get_token_reffs(conn::RedisConnection, token_id::Int, status::String)
        return Redis.smembers(conn, status * ":" * token * ":" * token.id)
    end

    function get_token_and_reffs(conn::RedisConnection, token_id::Int, status::String)
        token = get_token(conn, token_id)
        reffs = get_token_reffs(conn, token_id)
        return token, reffs
    end

    function get_tokens(conn::RedisConnection, token_ids::Array{Int, 1})
        tokens = [get_token(conn, token_id) for token_id in token_ids]
        return tokens
    end

    function get_tokens_reffs(conn::RedisConnection, token_ids::Array{Int, 1})
        reffs = [get_token_reffs(conn, token_id) for token_id in token_ids]
        return reffs
    end

    function get_tokens_and_reffs(conn::RedisConnection, token_ids::Array{Int, 1})
        tokens = get_tokens(conn, token_ids)
        reffs = get_tokens_reffs(conn, token_ids)
        return tokens, reffs
    end 
end