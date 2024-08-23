include("sets.jl")
include("utils.jl")

module HllGrad

    export Entity

    using ..HllSets

    # Base functions that we're going to be overriding 
    # import Base: ==, show, union, intersect, xor, comp, copy, negation, diff, adv

    # Operation
    struct Operation{FuncType,ArgTypes}
        op::FuncType
        args::ArgTypes
    end

    mutable struct Entity{P}
        sha1::String
        hll::HllSets.HllSet{P}
        grad::Float64
        op::Union{Operation{FuncType, ArgTypes}, Nothing} where {FuncType, ArgTypes}
        # Constructor with keyword arguments
        function Entity{P}(hll::HllSets.HllSet{P}; grad=0.0, op=nothing) where {P}
            sha1 = string(HllSets.id(hll))
            new{P}(sha1, hll, grad, op)
        end
    end

    function show(io::IO, entity::Entity)
        sha1_str = entity.sha1 === nothing ? "nothing" : string(entity.sha1)
        hll_str = entity.hll === nothing ? "nothing" : string(entity.hll)
        grad_str = entity.grad === nothing ? 0.0 : entity.grad
        op_str = entity.op === nothing ? "nothing" : string(entity.op)
        # println(io, "Entity(", sha1_str, "; ", hll_str, "; ", grad_str, "; ", op_str, ")")
        println(io, "\nEntity(sha1: ", sha1_str, ";\n hll_count: ", HllSets.count(entity.hll), ";\n grad: ", grad_str, ";\n op: ", op_str, ");\n")
    end

    function isequal(a::Entity, b::Entity)
        return HllSets.isequal(a.sha1, b.sha1) && a.grad == b.grad
    end

    #------------------------------------------------------------
    # Set of Entity operations to support Static Entity Structure
    #------------------------------------------------------------
    function copy(a::Entity{P}) where {P}
        return Entity{P}(HllSets.copy!(a.hll); grad=a.grad, op=a.op)
    end

    # negation
    function negation(a::Entity{P}) where {P}
        return Entity{P}(HllSets.copy!(a.hll); grad=-a.grad, op=a.op)
    end
    # union
    function union(a::Entity{P}, b::Entity{P}) where {P}
        hll_result = HllSets.union(a.hll, b.hll)
        op_result = Operation(union, (a, b))
        return Entity{P}(hll_result; grad=0.0, op=op_result)
    end

    # union backprop
    function backprop!(entity::Entity{P}, 
            entity_op::Union{Operation{FuncType, ArgTypes}, Nothing}=entity.op) where {P, FuncType<:typeof(union), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === union)
            entity_op.args[1].grad += entity.grad
            entity_op.args[2].grad += entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    # intersect - intersection
    function intersect(a::Entity{P}, b::Entity{P}) where {P}
        hll_result = HllSets.intersect(a.hll, b.hll)
        op_result = Operation(intersect, (a, b))
        return Entity{P}(hll_result; grad=0.0, op=op_result)
    end

    # intersect backprop
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(intersect), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === intersect)
            entity_op.args[1].grad += entity.grad
            entity_op.args[2].grad += entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    # xor 
    function xor(a::Entity{P}, b::Entity{P}) where {P}
        hll_result = HllSets.set_xor(a.hll, b.hll)
        op_result = Operation(xor, (a, b))
        return Entity{P}(hll_result; grad=0.0, op=op_result)
    end

    # xor backprop
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(xor), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === xor)
            entity_op.args[1].grad += entity.grad
            entity_op.args[2].grad += entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    # comp - complement returns the elements that are in the a set but not in the b
    function comp(a::Entity{P}, b::Entity{P}; opType=comp) where {P}
        # b should not be empty
        HllSets.count(b.hll) > 0  || throw(ArgumentError("HllSet{P} cannot be empty"))

        hll_result = HllSets.set_comp(a.hll, b.hll)
        op_result = Operation(comp, (a, b))
        comp_grad = HllSets.count(hll_result) / HllSets.count(a.hll)

        return Entity{P}(hll_result; grad=comp_grad, op=op_result)
    end

    # comp backprop
    # Technically this operation is changing first argument, so, it's not exactly a static operation.
    # We are keeping it here because it's not dynamic operation ether bur we are updating grad for the first argument.
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(comp), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === comp)
            entity_op.args[1].grad += entity.grad
            # entity_op.args[2].grad += entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    #------------------------------------------------------------
    # Set of Entity operations to support Dynamic Entity Structure
    #------------------------------------------------------------
    """
        This convenience methods that semantically reflect the purpose of using set_comp function
        in case of comparing two states of the same set now (current) and as it was before (previous).
        - set_added - returns the elements that are in the current set but not in the previous
        - set_deleted - returns the elements that are in the previous set but not in the current
    """
    function added(current::Entity{P}, previous::Entity{P}) where {P} 
        length(previous.hll.counts) == length(current.hll.counts) || throw(ArgumentError("HllSet{P} must have same size"))
        
        result = comp(previous, current)
        op_result = Operation(added, (current, previous))
        added_grad = result.grad

        return Entity{P}(result.hll; grad=added_grad, op=op_result)
    end

    # added backprop
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(added), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === added)
            # entity_op.args[1].grad *= entity.grad
            entity_op.args[2].grad *= entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    function deleted(current::Entity{P}, previous::Entity{P}) where {P} 
        length(previous.hll.counts) == length(current.hll.counts) || throw(ArgumentError("HllSet{P} must have same size"))

        result = comp(current, previous)
        op_result = Operation(deleted, (current, previous))
        deleted_grad = result.grad

        return Entity{P}(result.hll; grad=deleted_grad, op=op_result)
    end

    # deleted backprop
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(deleted), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === deleted)
            entity_op.args[1].grad *= entity.grad
            # entity_op.args[2].grad *= entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    function retained(current::Entity{P}, previous::Entity{P}) where {P} 
        length(previous.hll.counts) == length(current.hll.counts) || throw(ArgumentError("HllSet{P} must have same size"))
        
        hll_result = HllSets.intersect(current.hll, previous.hll)
        op_result = Operation(retained, (current, previous))
        retained_grad = HllSets.count(hll_result) / HllSets.count(HllSets.union(current.hll, previous.hll))

        return Entity{P}(hll_result; grad=retained_grad, op=op_result)
    end

    # retained backprop
    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(retained), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === retained)
            entity_op.args[1].grad *= entity.grad
            entity_op.args[2].grad *= entity.grad
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    # difference - diff 
    function diff(a::Entity{P}, b::Entity{P}) where {P}
        d = deleted(a, b)
        r = retained(a, b)
        n = added(a, b)
        return d, r, n
    end

    # diff  It is a shortcut to run 3 backprop! functions for deleted, retained, and added
    # function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(diff), ArgTypes}
    #     if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === diff)
    #         backprop!(entity, Operation(deleted, entity_op.args))
    #         backprop!(entity, Operation(retained, entity_op.args))
    #         backprop!(entity, Operation(added, entity_op.args))
    #     else
    #         println("Error: Operation not supported for terminal node")
    #     end
    # end

    # advance - Allows us to calculate the gradient for the advance operation
    # We are using 'advance' name to reflect the transformation of the set 
    # from the previous state to the current state
    function advance(a::Entity{P}, b::Entity{P}) where {P}
        d, r, n = diff(a, b)
        hll_res = HllSets.union(n.hll, r.hll)
        op_result = Operation(advance, (d, r, n))
        # calculate the gradient for the advance operation as 
        # the difference between the number of elements in the n set 
        # and the number of elements in the d set

        grad_res = HllSets.count(a.hll) / HllSets.count(b.hll)  # This is the simplest way to calculate the gradient
        
        # Create updated version of the entity
        return Entity{P}(hll_res; grad=grad_res, op=op_result)
    end

    """ 
        This version of advance operation generates new unknown set from the current set
        that we are using as previous set. 
        Entity b has some useful information about current state of the set:
            - b.hll - current state of the set
            - b.grad - gradient value that we are going to use to calculate the gradient for the advance operation
            - b.op - operation that we are going to use to calculate the gradient for the advance operation. 
                    op has information about how we got to the current set b.
                    - op.args[1] - deleted set
                    - op.args[2] - retained set
                    - op.args[3] - added set
        We are going to use this information to construct the new set that represents the unknown state of the set.
    """
    function advance(::Colon; b::Entity{P}) where {P}
        # Create a new empty set
        a = HllSets.create(b.hll)
        d, r, n = diff(a, b)
        op_result = Operation(advance, (d, r, n))
        # calculate the gradient for the advance operation as 
        # the number of elements in the a set
        grad_res = HllSets.count(a.hll)  # This is the simplest way to calculate the gradient
        
        # Create updated version of the entity
        return Entity{P}(hll_res; grad=grad_res, op=op_result)
    end

    function backprop!(entity::Entity{P}, entity_op::Operation{FuncType, ArgTypes}) where {P, FuncType<:typeof(advance), ArgTypes}
        if (entity.op != nothing) && (entity.op === entity_op) && (entity_op.op === advance)
            if entity_op.args[1].op !== nothing
                entity_op.args[1].grad *= entity.grad
            end
            if entity_op.args[2].op !== nothing                
                entity_op.args[2].grad *= entity.grad
            end
            if entity_op.args[3].op !== nothing
                entity_op.args[3].grad *= entity.grad
            end
        else
            println("Error: Operation not supported for terminal node")
        end
    end

    # function backward(a::Value)
    #     function build_topo(v::Value, visited=Value[], topo=Value[])
    #         if !(v in visited)
    #             push!(visited, v)
    #             if v.op != nothing
    #                 for operand in v.op.args
    #                     if operand isa Value
    #                         build_topo(operand, visited, topo)
    #                     end
    #                 end
    #             end
    #             push!(topo, v)
    #         end
    #         return topo
    #     end
        
    #     topo = build_topo(a)

    #     a.grad = 1.0
    #     for node in reverse(topo)
    #         backprop!(node)
    #     end
    # end

end # module SetGrad