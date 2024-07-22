include("graph.jl")

module Store 

    using ..HllGraph
    using ..Util

    using DataFrames: DataFrameRow
    using EasyConfig

    abstract type DataSource end
    
    #=============================================================================#
    # Assignment, Commit, Token
    #=============================================================================#
    struct Assignment <: HllGraph.AbstractGraphType
        id::String
        parent::String
        item::String
        a_type::String
        processor_id::String
        lock_uuid::String
        status::String
    end

    Assignmnent(id::String, parent::String, item::String, a_type::String, processor_id::String, lock_uuid::String, status::String) =
        Assignment(id, parent, item, a_type, processor_id, lock_uuid, status)
    Assignment(row::DataFrameRow) =
        Assignment(row.id, row.parent, row.item, row.a_type, row.processor_id, row.lock_uuid, row.status)
    Assignment(row::DataFrameRow) =
        Assignment(row.id, row.parent, row.item, row.a_type, row.processor_id, row.lock_uuid, row.status)

    function Base.show(io::IO, o::Assignment)
        print(io, "Assignment($(o.id), $(o.parent), $(o.item), $(o.a_type), $(o.processor_id), $(o.lock_uuid), $(o.status))")
    end

    args(b::Assignment) = (b.id, b.parent, b.item, b.a_type, b.processor_id, b.lock_uuid, b.status)

    #-----------------------------------------------------------------------------# Commit
    struct Commit <: HllGraph.AbstractGraphType
        id::String
        committer_name::String
        committer_email::String
        message::String
        props::Config
    end

    Commit(id::String, committer_name::String, committer_email::String, message::String, props...) = 
        Commit(id, committer_name, committer_email, message, Config(props))
    Commit(row::DataFrameRow) = 
        Commit(row.id, row.committer_name, row.committer_email, row.message, JSON3.read(row.props, Config))

    function Base.show(io::IO, o::Commit)
        print(io, "Commit($(o.id), $(o.committer_name), $(o.committer_email), ", repr(o.message))
        !isempty(o.props) && print(io, "; "); print_props(io, o.props)
        print(io, ')')
    end

    args(c::Commit) = (c.id, c.committer_name, c.committer_email, c.message, JSON3.write(c.props))
    

    #=============================================================================#
    # Store Util functions
    #=============================================================================#
    function process_file(root, file, db, ext, P, column)
        # TODO: Implement this function
        #------------------------------
        # f_name = joinpath(root, file)
        # sha_1 = bytes2hex(sha1(f_name))
        # assign = Store.Assignment(sha_1, root, f_name, ext, "book_file", "", "waiting")
        # Graph.replace!(db, assign)
        # dataset = [f_name, ext, root]
        # update_tokens(db, dataset, sha_1, P)
        # column && book_column(db, f_name, sha_1, P)
    end

    function process_directory(start_dir, db, ext, P, column)
        for (root, dirs, files) in walkdir(start_dir)
            for file in files
                if extension(file) == ext
                    process_file(root, file, db, ext, P, column)
                end
            end
        end
    end
end