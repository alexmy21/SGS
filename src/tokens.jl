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
    mutable struct Token 
        id::Int
        bin::Int
        zeros::Int
        token::String
        tf::Int
        refs::String
    end

    Token(id::Int, bin::Int, zeros::Int; token::String, tf::Int, refs::String) = Token(id, bin, zeros, token, tf, token)
    Token(row::DataFrameRow) = Token(row.id, row.bin, row.zeros, row.token, row.tf, row.refs)
    Token(dict::Dict{Symbol, Any}) = Token(dict.id, dict.bin, dict.zeros, dict.token, dict.tf, dict.refs)

    function Token(dict::Dict{AbstractString, AbstractString})
        id      = parse(Int, dict["id"])
        bin     = parse(Int, dict["bin"])
        zeros   = parse(Int, dict["zeros"])
        token   = dict["token"]
        tf      = parse(Int, dict["tf"])
        refs    = dict["refs"]
        return Token(id, bin, zeros, token, tf, refs)
    end

    function Base.show(io::IO, o::Token)
        print(io, "Token($(o.id), $(o.bin), $(o.zeros), $(o.token), $(o.tf), $(o.refs))")
    end

    args(t::Token) = (t.id, t.bin, t.zeros, t.token, t.tf, t.refs)
    dict(t::Token) = Dict(:id => t.id, :bin => t.bin, :zeros => t.zeros, :token => t.token, :tf => t.tf, :refs => t.refs)

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
        # Create hash key for token
        key_name = create_token_id(token.id, status)
        token_hash = Redis.hgetall(conn, key_name)
        
        if token_hash != nothing && !isempty(token_hash) 
            toc     = token_hash["token"]
            tocset  = Set(split(toc, ","))
            # update token.token in case we have new token with the same hash
            tocset = union(tocset, Set(split(token.token, ","))) 
            cnt_toc = join(tocset, ",")
            token.token = cnt_toc
            # update refrences if have new node.sha1
            refs    = token_hash["refs"]            
            refset  = Set(split(refs, ","))            
            if !in(refset, node_sha1)
                # Adjust tf and refs properties
                refset = union(refset, Set(split(node_sha1, ",")))                
                cnt_refs    = join(refset, ",")   
                token.refs  = cnt_refs
                token.tf    = token.tf + 1
            end
        end
        # Create new hash for token
        Redis.hmset(conn, key_name, Tokens.dict(token))
    end

    function set_tokens(conn::RedisConnection, tokens::Set{String}, node_sha1::String, status::String; P::Int=10, seed::Int=0)
        for token in tokens 
            # x = HllSets.u_hash(token, seed=seed)           
            key_name = create_token_id(token, status)
            # Assuming tf is retrieved from Redis and is a string
            _hash = Redis.hgetall(conn, key_name)
            # Check if tf_str is not nothing and then convert it to an integer
            if !(_hash == nothing || isempty(_hash))
                _token = Token(_hash)
                set_token(conn, _token, node_sha1, status)
            else
                _token = create_token(token, node_sha1)
                set_token(conn, _token, node_sha1, status)
            end 
        end
    end

    function create_token_id(token::String, status::String; seed::Int=0)
        return string(status, ":", "token", ":", HllSets.u_hash(token, seed=seed))
    end

    function create_token_id(id::Int, status::String)
        return string(status, ":", "token", ":", id)
    end

    # Creates new Token from token string and provided node_sha1
    function create_token(token::String, node_sha1; P::Int=10, seed::Int=0)
        x = HllSets.u_hash(token, seed=seed)
        _token = token
        bin = HllSets.getbin(x, P=P)
        zeros = HllSets.getzeros(x, P=P)
        tf = 0
        refs = node_sha1
        return Token(x, bin, zeros,_token, tf, refs)
    end

    function get_token(conn::RedisConnection, token_id::Int, status::String)
        key_name = create_token_id(token_id, status)
        token_dict = Redis.hgetall(conn, key_name)
        token = Token(token_dict)
        return token
    end

    function get_tokens(conn::RedisConnection, token_ids::Array{Int, 1}, status::String)
        tokens = [get_token(conn, token_id, status) for token_id in token_ids]
        return tokens
    end
    
    # token RediSearch index
    #--------------------------------------------------------------------------------------#
    """
        id::Int
        bin::Int
        zeros::Int
        token::String
        tf::Int
        refs::String
    """
    function token_idx(conn::RedisConnection, idx_name::String, idx_prefix::String)
        try
            Redis.execute_command(conn, ["FT.CREATE", "$idx_name", "ON", "HASH", "PREFIX", 1, "$idx_prefix", 
                "SCHEMA", "id", "NUMERIC", "bin", "NUMERIC", "zeros", "NUMERIC", 
                "token", "TEXT", "tf", "NUMERIC", "refs", "TEXT"])
        catch e
            println(e)
        end
    end
end