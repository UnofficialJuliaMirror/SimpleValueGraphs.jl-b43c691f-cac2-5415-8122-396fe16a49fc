using LightGraphs
using SimpleValueGraphs
using Test

using Base.Iterators: product

include("testutils.jl")

tests = [
         "interface/constructors.jl",
         "interface/edges.jl",
         "interface/edgeval_accessors.jl",
         "interface/iterators.jl",
         "interface/valuegraph.jl",
        ]

@testset "ValueGraphs" begin
    for (i, test) in enumerate(tests)
        println("$i / $(length(tests)) $test")
        @time include(test)
    end
end # testset
