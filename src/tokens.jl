include("sets.jl")

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

    Token(id::Int, bin::Int, zeros::Int; token::String, tf::Int) = Token(id, bin, zeros, token, tf)
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
    dict(t::Token) = Dict(:id => t.id, :bin => t.bin, :zeros => t.zeros, :token => JSON3.write(t.token))

    # Tokens operations
    #-----------------------------------------------------------------------------#    
    function set_token(conn::RedisConnection, token::Token, node_sha1::String, status::String)
        token_dict = dict(token)        
        key_name = status * ":" * token * ":" * token.id
        Redis.hmset(conn, key_name, token_dict)
        Redis.sadd(conn, token.id, node_sha1)
    end

    function get_token(conn::RedisConnection, token_id::Int, status::String)
        key_name = status * ":" * token * ":" * token.id
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