

abstract type AbstractValEdge{V <: Integer, E_VALS} <: AbstractEdge{V} end

"""
    ValEdge{V, E_VALS} <: AbstractValEdge{V}

A datastructure representing an undirected edge with multiple values.
"""
struct ValEdge{V<:Integer, E_VALS} <: AbstractValEdge{V, E_VALS}
    src::V
    dst::V
    vals::E_VALS

    function ValEdge(src::V, dst::V, vals::E_VALS) where {V, E_VALS}
        src, dst = minmax(src, dst) # TODO maybe use a branchless operator
        return new{V, E_VALS}(src, dst, vals)
    end
end

# TODO update docstring and ValDiEdge
"""
    ValEdge(s, d, v)
Create a `ValEdge` with source `s`, destination `d` and value `v`.
# Examples
```
julia> e = ValEdge(4, 2, 'A')
Edge 4 => 2 with value 'A'
```
"""
function ValEdge end

"""
    ValDiEdge{V, E_VALS} <: AbstractValEdge{V}

A datastructure representing a directed edge with values.
"""
struct ValDiEdge{V<:Integer, E_VALS} <: AbstractValEdge{V, E_VALS}
    src::V
    dst::V
    vals::E_VALS

    function ValDiEdge(src::V, dst::V, vals::E_VALS) where {V, E_VALS}
        return new{V, E_VALS}(src, dst, vals)
    end
end

src(e::AbstractValEdge) = e.src
dst(e::AbstractValEdge) = e.dst

"""
    vals(e::ValEdge)
Returns the value attached to the edge `e`.
# Examples
```
julia> g = EdgeValGraph(3, String)

julia> add_edge!(g, 2, 3, ("xyz",))

julia> first(edges(g)) |> vals
"xyz"
```
"""
vals(e::AbstractValEdge) = e.vals

# TODO Maybe that should be declared somewhere else
const SingleValTuple{T} = Union{Tuple{T}, NamedTuple{S, Tuple{T}} where {S}}

val(e::AbstractValEdge; key::Union{Integer, Symbol, NoKey}=nokey) =
    _val(e, key)

_val(e::AbstractValEdge{V, E_VAL}, ::NoKey) where {V, E_VAL <: SingleValTuple} =
    e.vals[1]

_val(e::AbstractValEdge, key::Union{Integer, Symbol}) = e.vals[key]

reverse(e::ValEdge) = e
reverse(e::ValDiEdge) = ValDiEdge(dst(e), src(e), vals(e))


is_directed(::Type{<:ValEdge}) = false
is_directed(::Type{<:ValDiEdge}) = true
is_directed(e::AbstractValEdge) = is_directed(typeof(e))

function show(io::IO, e::AbstractValEdge)
    isdir = is_directed(e) 
    e_keys = keys(vals(e))
    has_symbol_keys = eltype(e_keys) === Symbol

    print(io, isdir ? "ValDiEdge" : "ValEdge")
    arrow = isdir ? "->" : "--"
    print(io, " $(src(e)) $arrow $(dst(e))")

    if length(e_keys) == 1
        print(io, " with value " * (has_symbol_keys ? "$(e_keys[1]) = $(val(e))" :
                                                      "$(val(e))"))
    elseif length(e_keys) > 1
        print(io, " with values $(vals(e))")
    end

    println(io)
end


