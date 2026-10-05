# Run on Julia 0.6.4 ONLY (oracle):  julia generate.jl   -> writes golden-0.6.json
VERSION < v"0.7" || error("generate.jl must be run on Julia 0.6 (the oracle runtime)")
using TTCal
using CasaCore.Measures
using CasaCore.Tables
using Unitful, UnitfulAstro
using JSON, JLD2
include(joinpath(@__DIR__, "compute.jl"))

inp = make_inputs()
golden = golden_all(inp)
golden["inputs"] = inp
golden["generated_with"] = string(VERSION)
open(joinpath(@__DIR__, "golden-0.6.json"), "w") do io
    JSON.print(io, golden, 1)
end
println("wrote ", joinpath(@__DIR__, "golden-0.6.json"))
