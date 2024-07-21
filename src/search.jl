include("sets.jl")

module Tokens
    using ..HllSets
    using ..Util

    # using TidierDB
    using Redis
    using JSON3: JSON3
    using EasyConfig
    using DataFrames: DataFrame
    using DataFrames: DataFrameRow

    export SearchIndex, SearchIndexRow, SearchIndexRowDict, SearchIndexRowRedis

    struct Token 
        id::Int
        bin::Int
        zeros::Int
        token::Set{String}
        tf::Int
        refs::String
    end

    Token(id::Int, bin::Int, zeros::Int; token::String, tf::Int, refs::String) = 
        Token(id, bin, zeros, token, tf, refs)
    Token(row::SQLite.Row) = Token(row.id, row.bin, row.zeros, JSON3.read(row.token), row.tf, JSON3.read(row.refs))

    function Base.show(io::IO, o::Token)
        print(io, "Token($(o.id), $(o.bin), $(o.zeros), $(o.token), $(o.tf), $(o.refs))")
    end





end