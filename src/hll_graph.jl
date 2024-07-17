"""
MIT License

Copyright (c) 2022: Julia Computing Inc. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Source code is on github
https://github.com/JuliaComputing/SQLiteGraph.jl.git

I borrowed a lot from this project, but also made a lot of changes, 
so, for all errors do not blame the original author but me.
"""


include("hll_sets.jl")
include("hll_util.jl")

module Graph

    using ..HllSets
    using ..Util

    # using TidierDB
    using Redis
    using JSON3: JSON3
    using EasyConfig
    using DataFrames: DataFrame
    using DataFrames: DataFrameRow

    export Node, Edge

    abstract type AbstractGraphType end

    #-----------------------------------------------------------------------------# Node
    struct Node <: AbstractGraphType
        sha1::String
        labels::Vector{String}
        # d_sha1::String
        # card::Int
        dataset::Vector{Int}
        # props::Config
    end

    Node(sha1::String, labels::Vector{String}=Vector{String}(), dataset::Vector{Int}=Vector{Int}()) = 
        Node(sha1, collect(labels), dataset)
    Node(row::DataFrameRow) = 
        Node(row.sha1, JSON3.read(row.labels), JSON3.read(row.dataset, Vector{Int}))

    function Base.show(io::IO, o::Node)
        print(io, "Node($(o.sha1)")
        print(io, "; ") 
        print(io, o.labels)
        # print(io, "; ")
        # !isempty(o.props) && print(io, "props: "); Util.print_props(io, o.props)
        print(io, ')')
    end

    args(n::Node) = (n.sha1, JSON3.write(n.labels), JSON3.write(n.dataset))

    #-----------------------------------------------------------------------------# Edge
    struct Edge <: AbstractGraphType
        source::String
        target::String
        r_type::String
        props::Config
    end

    Edge(src::String, tgt::String, r_type::String; props...) = Edge(src, tgt, r_type, Config(props))
    Edge(row::DataFrameRow) = Edge(row.source, row.target, row.r_type, JSON3.read(row.props, Config))

    function Base.show(io::IO, o::Edge)
        print(io, "Edge($(o.source), $(o.target), ", repr(o.r_type))
        !isempty(o.props) && print(io, "; "); print_props(io, o.props)
        print(io, ')')
    end

    args(e::Edge) = (e.source, e.target, e.r_type, JSON3.write(e.props))

    #-----------------------------------------------------------------------------# Base methods
    Base.:(==)(a::Node, b::Node) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Node))
    Base.:(==)(a::Edge, b::Edge) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Edge))

    Base.pairs(o::T) where {T<: Union{Node, Edge}} = (f => getfield(o,f) for f in fieldnames(T))

    Base.NamedTuple(o::Union{Node,Edge}) = NamedTuple(pairs(o))     
    
    # Graph operations
    #-----------------------------------------------------------------------------#    
    function set_node(conn::RedisConnection, node::Graph.Node, status::String)
        node_dict = Util.struct_to_dict(node)
        tag_name = status * ":" * "n" * ":" * node.sha1
        Redis.hmset(conn, tag_name, node_dict)
    end

    function set_edge(conn::RedisConnection, edge::Graph.Edge, status::String)
        edge_dict = Util.struct_to_dict(edge)
        tag_name = status * ":" * "e" * ":" * edge.source * ":" * edge.target
        Redis.hmset(conn, tag_name, edge_dict)
    end

    # Implement get_node and get_edge functions
    #-----------------------------------------------------------------------------#
    function get_node(conn::RedisConnection, sha1::String, status::String)
        tag_name = status * ":" * "n" * ":" * sha1
        node_dict = Redis.hgetall(conn, tag_name)

        println("node_dict: ", node_dict)

        return Util.dict_to_struct(node_dict, Graph.Node)
    end

    function get_edge(conn::RedisConnection, source::String, target::String, status::String)
        tag_name = status * ":" * "e" * ":" * source * ":" * target
        edge_dict = Redis.hgetall(conn, tag_name)
        return Util.dict_to_struct(edge_dict, Graph.Edge)
    end

    # Implement get_nodes and get_edges functions to get multiple nodes and edges
    #-----------------------------------------------------------------------------#
    function get_nodes(conn::RedisConnection, status::String)
        nodes = []
        cursor = 0
        pattern = status * ":n:*"
        while true
            cursor, keys = Redis.scan(conn, cursor, "match", pattern)
            # println("cursor: ", cursor)
            for key in keys
                # println("key: ", key)
                node_dict = Redis.hgetall(conn, key)
                push!(nodes, Util.dict_to_struct(node_dict, Graph.Node))
            end
            # Check the condition at the end of the loop body
            if cursor == 0
                break  # Exit the loop if the condition is met
            end
        end
        return nodes
    end

    function get_edges(conn::RedisConnection, status::String)
        edges = []
        cursor = 0
        pattern = status * ":e:*"
        while true
            cursor, keys = Redis.scan(conn, cursor, "match", pattern)
            # println("cursor: ", cursor)
            for key in keys
                edge_dict = Redis.hgetall(conn, key)
                push!(edges, Util.dict_to_struct(edge_dict, Graph.Edge))
            end
            # Check the condition at the end of the loop body
            if cursor == 0
                break  # Exit the loop if the condition is met
            end
        end
        return edges
    end

    # Set operations on Nodes
    #-----------------------------------------------------------------------------#
    function union_nodes(node_1::{Node}, node_2::{Node}, labels::Vector{String})
        union_hll = HllSets.union(to_hll_set(node_1), to_hll_set(node_2))
        union_sha1 = sha1_union([node_1.sha1, node_2.sha1])
        
        return Node(sha1, collect(labels), HllSets.dump(union_hll))
    end

    function intersect_nodes(node_1::{Node}, node_2::{Node}, labels::Vector{String})
        intersect_hll = HllSets.intersection(to_hll_set(node_1), to_hll_set(node_2))
        intersect_sha1 = sha1_intersect([node_1.sha1, node_2.sha1])
        
        return Node(intersect_sha1, collect(labels), HllSets.dump(intersect_hll))
    end

    function comp_nodes(node_1::{Node}, node_2::{Node}, labels::Vector{String})
        comp_hll = HllSets.complement(to_hll_set(node_1), to_hll_set(node_2))
        comp_sha1 = sha1_comp(node_1.sha1, node_2.sha1)
        
        return Node(comp_sha1, collect(labels), HllSets.dump(comp_hll))
    end

    function xor_nodes(node_1::{Node}, node_2::{Node}, labels::Vector{String})
        xor_hll = HllSets.xor(to_hll_set(node_1), to_hll_set(node_2))
        xor_sha1 = sha1_xor(node_1.sha1, node_2.sha1)
        
        return Node(xor_sha1, collect(labels), HllSets.dump(xor_hll))
    end

    # Compound functions that perform Set operations on Nodes and submit the results
    # to the Redis db. These function also create edges between the input nodes and the
    # result node.
    #-----------------------------------------------------------------------------#
    function union_nodes(conn::RedisConnection, node_1::{Node}, node_2::{Node}, labels::Vector{String}, status::String)
        union_node = union_nodes(node_1, node_2, labels)
        edge_1 = Edge(node_1.sha1, union_node.sha1, "union")
        edge_2 = Edge(node_2.sha1, union_node.sha1, "union")

        set_node(conn, union_node, status)
        set_edge(conn, edge_1, status)
        set_edge(conn, edge_2, status)

        return union_node
    end

    function intersect_nodes(conn::RedisConnection, node_1::{Node}, node_2::{Node}, labels::Vector{String}, status::String)
        intersect_node = intersect_nodes(node_1, node_2, labels)
        edge_1 = Edge(node_1.sha1, intersect_node.sha1, "intersect")
        edge_2 = Edge(node_2.sha1, intersect_node.sha1, "intersect")

        set_node(conn, intersect_node, status)
        set_edge(conn, edge_1, status)
        set_edge(conn, edge_2, status)

        return intersect_node
    end

    function comp_nodes(conn::RedisConnection, node_1::{Node}, node_2::{Node}, labels::Vector{String}, status::String)
        comp_node = comp_nodes(node_1, node_2, labels)
        edge_1 = Edge(node_1.sha1, comp_node.sha1, "comp")
        edge_2 = Edge(node_2.sha1, comp_node.sha1, "comp")

        set_node(conn, comp_node, status)
        set_edge(conn, edge_1, status)
        set_edge(conn, edge_2, status)

        return comp_node
    end

    function xor_nodes(conn::RedisConnection, node_1::{Node}, node_2::{Node}, labels::Vector{String}, status::String)
        xor_node = xor_nodes(node_1, node_2, labels)
        edge_1 = Edge(node_1.sha1, xor_node.sha1, "xor")
        edge_2 = Edge(node_2.sha1, xor_node.sha1, "xor")

        set_node(conn, xor_node, status)
        set_edge(conn, edge_1, status)
        set_edge(conn, edge_2, status)
        
        return xor_node
    end

    # Implement intersection_nodes function
    #-----------------------------------------------------------------------------#
    function to_hll_set(node::Node; P::Int=10)
        z = HllSet{P}()
        return HllSets.restore(z, node.dataset)
    end


    # Function to create arrays of SHA1 strings and HLLSets from a set of Nodes
    function get_sha1_hll(nodes::Set{Node}; P::Int=10)
        sha1_array = String[]
        hllSet_array = Any[]  # Replace `Any` with the actual type of your HLLSet

        for node in nodes
            z = HllSet{P}()
            push!(sha1_array, node.sha1)
            push!(hllSet_array, to_hll_set(node))
        end

        return sha1_array, hllSet_array
    end


end



