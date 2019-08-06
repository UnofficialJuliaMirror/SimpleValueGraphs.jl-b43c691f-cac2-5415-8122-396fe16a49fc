using BenchmarkTools, LightGraphs, SimpleValueGraphs

const SUITE = BenchmarkGroup()

SUITE["floyd_warshall"] = BenchmarkGroup()


SUITE["floyd_warshall"]["SimpleGraph"] = @benchmarkable floyd_warshall_shortest_paths($(StarGraph(2*10^3)))
SUITE["floyd_warshall"]["ValueGraph"] = @benchmarkable floyd_warshall_shortest_paths($(ValueGraph(undef, StarGraph(2*10^3), ())))
