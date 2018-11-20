
#  ======================================================
#  Constructors
#  ======================================================


const EdgeValContainer{T} = Any # TODO make more concrete

mutable struct SimpleValueGraph{V<:Integer, E_VAL, E_VAL_C <: EdgeValContainer} <: AbstractSimpleValueGraph{V, E_VAL}
    ne::Int
    fadjlist::Adjlist{V}
    edge_vals::E_VAL_C
end

create_edge_val_list(nv, E_VAL::Type) = Adjlist{E_VAL}(nv)
create_edge_val_list(nv, E_VAL::Type{<:Tuple}) = Tuple(Adjlist{T}(nv) for T in E_VAL.parameters)
create_edge_val_list(nv, E_VAL::Type{<:NamedTuple}) = NamedTuple{Tuple(E_VAL.names)}(Adjlist{T}(nv) for T in E_VAL.types)

function SimpleValueGraph(nv::V, E_VAL::Type) where {V<:Integer}
    fadjlist = Adjlist{V}(nv)
    edge_vals = create_edge_val_list(nv, E_VAL)
    return SimpleValueGraph{V, E_VAL, typeof(edge_vals)}(0, fadjlist, edge_vals)
end

SimpleValueGraph(nv::Integer) = SimpleValueGraph(nv::Integer, default_edge_val_type)
SimpleValueGraph{V, E_VAL}(n::V) where {V, E_VAL} = SimpleValueGraph(n, E_VAL)

SimpleValueGraph(g::SimpleGraph) = SimpleValueGraph(g, default_edge_val_type)

# TODO rewrite for tuples and named tuples
function SimpleValueGraph(g::SimpleGraph{V}, ::Type{E_VAL}) where {V, E_VAL}
    n = nv(g)
    ne_ = ne(g)
    fadjlist = deepcopy(g.fadjlist)
    edge_vals = Vector{Vector{E_VAL}}(undef, n)
    for u in Base.OneTo(n)
        len = length(fadjlist[u])
        edge_vals[u] = [default_edge_val(E_VAL) for _ in Base.OneTo(len)]
    end
    SimpleValueGraph{V, E_VAL, typeof(edge_vals)}(ne_, fadjlist, edge_vals)
end



# =========================================================
# Interface
# =========================================================

# TODO maybe move somewhere else
function set_value_for_index!(g::SimpleValueGraph{V, E_VAL}, s::V, index::Integer, value::E_VAL) where {V, E_VAL}
    @inbounds g.edge_vals[s][index] = value
    return nothing
end

function set_value_for_index!(g::SimpleValueGraph{V, E_VAL}, s::V, index::Integer, value::E_VAL) where {V, E_VAL <: TupleOrNamedTuple}
    @inbounds for i in eachindex(value)
        g.edgevals[i][s][index] = value[i]
    end
    return nothing
end

# TODO maybe move somewhere else
function insert_value_for_index!(g::SimpleValueGraph{V, E_VAL},
                                 s::V,
                                 index::Integer,
                                 value::E_VAL) where {V, E_VAL}
    @inbounds insert!(g.edge_vals[s], index, value)
    return nothing
end

function insert_value_for_index!(g::SimpleValueGraph{V, E_VAL},
                                 s::V,
                                 index::Integer,
                                 value::E_VAL) where {V, E_VAL <: TupleOrNamedTuple}
    @inbounds for i in eachindex(value)
        insert!(g.edgevals[i][s], index, value[i])
    end
    return nothing
end


function add_edge!(g::SimpleValueGraph{V, E_VAL},
                   s::V,
                   d::V,
                   value::E_VAL=default_edge_val(E_VAL)) where {V, E_VAL}
    verts = vertices(g)
    (s in verts && d in verts) || return false # edge out of bounds
    @inbounds list = g.fadjlist[s]
    index = searchsortedfirst(list, d)
    @inbounds if index <= length(list) && list[index] == d
        # edge already there, replace value, but return false
        index = searchsortedfirst(g.fadjlist[d], s)
        set_value_for_index!(g, s, index, value)
        return false
    end

    insert!(list, index, d)
    insert_value_for_index!(g, s, index, value)
    g.ne += 1

    s == d && return true # selfloop

    @inbounds list = g.fadjlist[d]
    index = searchsortedfirst(list, s)
    insert!(list, index, s)
    insert_value_for_index!(g, d, index, value)
    return true # edge successfully added
end

add_edge!(g::SimpleValueGraph, e::SimpleEdge)      = add_edge!(g, src(e), dst(e))
add_edge!(g::SimpleValueGraph, e::SimpleEdge, u)   = add_edge!(g, src(e), dst(e), u)
add_edge!(g::SimpleValueGraph, e::SimpleValueEdge) = add_edge!(g, src(e), dst(e), edge_val(e))

# TODO maybe move somewhere else
function delete_value_for_index!(g::SimpleValueGraph{V, E_VAL},
                                 s::V,
                                 index::Integer) where {V, E_VAL}
    @inbounds deleteat!(g.edge_vals[s], index)
    return nothing
end

function delete_value_for_index!(g::SimpleValueGraph{V, E_VAL},
                                 s::V,
                                 index::Integer) where {V, E_VAL <: TupleOrNamedTuple}
    @inbounds for i in eachindex(value)
        deleteat!(g.edge_vals[i][s], index)
    end
    return nothing
end


function rem_edge!(g::SimpleValueGraph{T, U}, s::T, d::T) where {T, U}
    verts = vertices(g)
    (s in verts && d in verts) || return false # edge out of bounds
    @inbounds list = g.fadjlist[s]
    index = searchsortedfirst(list, d)
    @inbounds (index <= length(list) && list[index] == d) || return false
    deleteat!(list, index)
    delete_value_for_index!(g, s, index)
    deleteat!(g.edge_vals[s], index)

    g.ne -= 1
    s == d && return true # self-loop

    @inbounds list = g.fadjlist[d]
    index = searchsortedfirst(list, s)
    deleteat!(list, index)
    delete_value_for_index!(g, s, index)

    return true
end

rem_edge!(g::SimpleValueGraph, e::SimpleEdge) = rem_edge!(g, src(e), dst(e))
rem_edge!(g::SimpleValueGraph, e::SimpleValueEdge) = rem_edge!(g, src(e), dst(e))


# TODO rem_vertex!, rem_vertices!


function has_edge(g::SimpleValueGraph{T}, s::T, d::T) where {T}
    verts = vertices(g)
    (s in verts && d in verts) || return false # edge out of bounds
    @inbounds list_s = g.fadjlist[s]
    @inbounds list_d = g.fadjlist[d]
    if length(list_s) > length(list_d)
        d = s
        list_s = list_d
    end
    return LightGraphs.insorted(d, list_s)
end

# TODO maybe move this function somewhere else
function value_for_index(g::SimpleValueGraph{V, E_VAL}, s::V, index::Integer) where {V, E_VAL}
    @inbounds return g.edge_vals[s][index]
end

function value_for_index(g::SimpleValueGraph{V, E_VAL}, s::V, index::Integer) where {V, E_VAL <: TupleOrNamedTuple}
    @inbounds return E_VAL( adjlist[s][index] for adjlist in g.edge_vals )
end

function has_edge(g::SimpleValueGraph{T, U}, s::T, d::T, value::U) where {T, U}
    verts = vertices(g)
    (s in verts && d in verts) || return false # edge out of bounds
    @inbounds list_s = g.fadjlist[s]
    @inbounds list_d = g.fadjlist[d]
    if length(list_s) > length(list_d)
        s, d = d, s
        list_s = list_d
    end
    index = searchsortedfirst(list_s, d)
    @inbounds return (index <= length(list_s) && list_s[index] == d && val_for_index(g, s, index) == value)
end


has_edge(g::SimpleValueGraph, e::SimpleEdge)      = has_edge(g, src(e), dst(e))
has_edge(g::SimpleValueGraph, e::SimpleEdge, u)   = has_edge(g, src(e), dst(e), u)
has_edge(g::SimpleValueGraph, e::SimpleValueEdge) = has_edge(g, src(e), dst(e), edge_val(e))

# TODO rest methods for get_value
function get_value(g::SimpleValueGraph{T, U}, s::T, d::T, default=default_zero_edge_val(U)) where {T, U}
     verts = vertices(g)
    (s in verts && d in verts) || return default # TODO may raise bounds error?
    @inbounds list_s = g.fadjlist[s]
    @inbounds list_d = g.fadjlist[d]
    if length(list_s) > length(list_d)
        s, d = d, s
        list_s = list_d
    end
    index = searchsortedfirst(list_s, d)
    @inbounds if index <= length(list_s) && list_s[index] == d
        return val_for_index(g, s, index)
    end
    return default    
end

function set_value!(g::SimpleValueGraph{T, U}, s::T, d::T, value::U) where {T, U}
     verts = vertices(g)
    (s in verts && d in verts) || return false
    @inbounds list = g.fadjlist[s]
    index = searchsortedfirst(list, d)
    @inbounds index <= length(list) && list[index] == d || return false
    set_value_for_index!(g, s, index, value)

    @inbounds list = g.fadjlist[d]
    index = searchsortedfirst(list, s)
    set_value_for_index!(g, d, index, value)

    return true
end

# TODO maybe move this function somewhere else
set_value!(g::SimpleValueGraph, e::SimpleEdge, u)   = set_value!(g, src(e), dst(e), u)
set_value!(g::SimpleValueGraph, e::SimpleValueEdge) = set_value!(g, src(e), dst(e), edge_val(e))


is_directed(::Type{<:SimpleValueGraph})       = false
is_directed(g::SimpleValueGraph) where {T, U} = false


outneighbors(g::SimpleValueGraph{T, U}, v::T) where {T, U} = g.fadjlist[v]
inneighbors(g::SimpleValueGraph{T, U}, v::T) where {T, U} = outneighbors(g, v) 

outedgevals(g::SimpleValueGraph{T, U}, v::T) where {T, U} =
    g.edge_vals[v]
inedgevals(g::SimpleValueGraph{T, U}, v::T) where {T, U} =
    outedgevals(g, v)
# edgevals(g::SimpleValueGraph{T, U}, v::T) where {T, U} =
    #outedgevals(g, v)
all_edgevals(g::SimpleValueGraph{T, U}, v::T) where {T, U} =
    outedgevals(g, v)



function add_vertex!(g::SimpleValueGraph{V, E_VAL}) where {V, E_VAL}
    # TODO There are overflow checks in Julia Base, use these
    (nv(g) + one(V) <= nv(g)) && return false # overflow
    push!(g.fadjlist, V[])
    if E_VAL <: TupleOrNamedTuple
        for (i, T) in enumerate(E_VAL.types)
            push!(g.edge_vals[i], T[])
        end
    else
        push!(g.edge_vals, E_VAL[])
    end
    return true
end

# ====================================================================
# Iterators
# ====================================================================


function iterate(iter::SimpleValueEdgeIter{<:SimpleValueGraph}, state=(one(eltype(iter.g)), 1) )
    g = iter.g
    fadjlist = g.fadjlist
    V = eltype(g)
    n::V = nv(g)
    u::V, i = state

    @inbounds while u < n
        if i > length(fadjlist[u])
            u += V(1)
            i = searchsortedfirst(fadjlist[u], u)
            continue
        end
        e = SimpleValueEdge(u, fadjlist[u][i], value_for_index(g, u, i))
        return e, (u, i + 1)
    end
    
    (n == 0 || i > length(fadjlist[n])) && return nothing

    e = SimpleValueEdge(n, n, value_for_index(g, n, 1))
    return e, (u, i + 1)
end


