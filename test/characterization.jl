# Characterization tests: pin Julia 0.6.4 behaviour of numerical paths (golden/golden-0.6.json,
# produced by golden/generate.jl on 0.6) so a Julia >= 0.7 port can be checked (dual-run).
# Run from this directory:  julia characterization.jl      (see golden/README.md)
using TTCal
@static if VERSION < v"0.7"   # 0.6 oracle run uses the original CasaCore.jl
    using CasaCore.Measures
    using CasaCore.Tables
else
    using CasaCoreCompat.Measures
    using CasaCoreCompat.Tables
end
using Unitful, UnitfulAstro
using JSON, JLD2
include(joinpath(@__DIR__, "golden", "compute.jl"))

const GOLDEN = JSON.parsefile(joinpath(@__DIR__, "golden", "golden-0.6.json"); dicttype=Dict)  # JSON >= 1.0 returns JSON.Object by default
const INP = GOLDEN["inputs"]

const TOL_MATH  = 1e-10   # pure math
const TOL_OPT   = 1e-6    # NLopt / iterative solvers
const TOL_FRAME = 1e-8    # rad, ephemeris vintage

flat_json(x::Number) = Float64[x]
flat_json(x::AbstractVector) = Float64[v for e in x for v in flat_json(e)]

# 0.6 used the per-element spectral 2-norm because the Jones types subtype AbstractMatrix; 1.x
# uses Frobenius (architect-approved behaviour change, see UPLIFT_NOTES). On >= 0.7, compare
# norm(J) against the recorded `frobenius` entry and vector norms against the `l2_*` entries.
function norm_golden(k, gold)
    VERSION < v"0.7" && return gold[k]
    k == "norm" && haskey(gold, "frobenius") && return gold["frobenius"]
    m = match(r"^norm_(?:diff_)?(.*)$", k)
    m !== nothing && haskey(gold, "l2_"*m.captures[1]) && return gold["l2_"*m.captures[1]]
    gold[k]
end

# Type names print with aliases on 1.x ("ComplexF64" vs 0.6 "Complex{Float64}").
normtype(s) = VERSION < v"0.7" ? s :
    replace(replace(s, "Complex{Float64}" => "ComplexF64"), "Complex{Float32}" => "ComplexF32")

# Walk the golden tree: every leaf in `cur` must match the golden leaf.
# `keytol` overrides `tol` for individual leaf keys.
function compare_tree(cur::Dict, gold::Dict, tol, path=""; keytol=Dict{String,Float64}())
    @test Set(keys(cur)) == Set(k for k in keys(gold) if k != "inputs" && k != "generated_with")
    for (k, g) in gold
        haskey(cur, k) || continue
        c = cur[k]
        if g isa Dict
            compare_tree(c, g, tol, path*"/"*k; keytol=keytol)
        else
            g = norm_golden(k, gold)
            ok = check_leaf(c, g, get(keytol, k, tol))
            ok || println("MISMATCH at $path/$k\n  current: $c\n  golden:  $g")
            @test ok
        end
    end
end
function check_leaf(c, g, tol)
    g isa AbstractString && return c isa AbstractString && normtype(c) == normtype(g)
    g isa Bool && return c == g
    c isa AbstractString && return false
    c isa Bool && return false
    gf = Float64[x for x in flat_json(g)]
    cf = c isa Number ? [Float64(c)] : Float64[x for x in flat(c)]
    length(cf) == length(gf) || return false
    l2norm(cf .- gf) <= tol * max(l2norm(gf), 1e-300)
end
# Boolean/Int/Vector{Int} leaves (iteration counts) must match exactly.
# Exception: StefCal iteration counts may differ by a few steps because norm() of Jones
# matrices is Frobenius-based on Julia >= 0.7 (0.6 used the spectral 2-norm per element);
# the solved gains are still compared at TOL_OPT.
check_leaf(c::Vector{Int}, g, tol) = length(c) == length(g) && all(abs.(c .- Int[x for x in g]) .<= 3)
check_leaf(c::Bool, g::Bool, tol) = c == g

@testset "characterization (golden from Julia $(GOLDEN["generated_with"]), running $VERSION)" begin

    @testset "(a) Jones algebra" begin
        cur = golden_jones(INP)
        compare_tree(cur, GOLDEN["jones"], TOL_MATH)
    end

    @testset "(b) norms and Runge-Kutta" begin
        compare_tree(golden_norms_rk(INP), GOLDEN["norms_rk"], TOL_MATH)
    end

    @testset "(c) PowerLaw spectrum, Hz and MHz" begin
        compare_tree(golden_spectrum(), GOLDEN["spectrum"], TOL_MATH)
    end

    @testset "(d) geometric delays and fringes" begin
        compare_tree(golden_delays(INP), GOLDEN["delays"], TOL_MATH)
    end

    @testset "(e) genvis one-source" begin
        # The J2000->ITRF conversion differs by ~4e-12 rad between casacore 3.5 (0.6 build) and
        # casacore_jll 3.7.1; the baseline phase 2πντ amplifies that to ~4e-10 relative in the
        # visibilities, so those use TOL_FRAME. sum_abs2 stays at TOL_MATH.
        compare_tree(golden_genvis(INP), GOLDEN["genvis"], TOL_MATH;
                     keytol=Dict("vis_first8" => TOL_FRAME, "dual_vis_first8" => TOL_FRAME))
    end

    @testset "(f) calibrate" begin
        compare_tree(golden_calibrate(INP), GOLDEN["calibrate"], TOL_OPT)
    end

    @testset "(g) fitvis" begin
        compare_tree(golden_fitvis(INP), GOLDEN["fitvis"], TOL_OPT)
    end

    @testset "(i) frame conversions" begin
        cur = golden_frames()
        gold = GOLDEN["frames"]
        @test cur["ovro_itrf_m"] ≈ Float64.(gold["ovro_itrf_m"]) rtol=1e-9
        for (k, g) in gold
            k == "ovro_itrf_m" && continue
            lon, lat = cur[k]; glon, glat = g
            dlon = mod(lon - glon + π, 2π) - π
            @test abs(dlon) < TOL_FRAME || (abs(lat) > π/2 - 1e-6)
            @test abs(lat - glat) < TOL_FRAME
        end
    end
end

# ---- (h) JLD2 round trips (self-contained: runs on whichever runtime executes it) ----------
function same_metadata(a::TTCal.Metadata, b::TTCal.Metadata)
    a.frequencies == b.frequencies &&
    length(a.times) == length(b.times) &&
    all(flat(Float64[ustrip(x.time) for x in a.times]) .== flat(Float64[ustrip(x.time) for x in b.times])) &&
    all([(p.x, p.y, p.z) == (q.x, q.y, q.z) for (p, q) in zip(a.positions, b.positions)]) &&
    all([(rad(longitude(p)), rad(latitude(p))) == (rad(longitude(q)), rad(latitude(q)))
         for (p, q) in zip(a.phase_centers, b.phase_centers)])
end
function same_dataset(a::TTCal.Dataset, b::TTCal.Dataset)
    typeof(a) == typeof(b) && same_metadata(a.metadata, b.metadata) && size(a.data) == size(b.data) &&
    all(a.data[i].flags == b.data[i].flags && flat(a.data[i].data) == flat(b.data[i].data)
        for i in eachindex(a.data))
end
function same_calibration(a::TTCal.Calibration, b::TTCal.Calibration)
    typeof(a) == typeof(b) && size(a.data) == size(b.data) &&
    all(flat(a.data[i].data) == flat(b.data[i].data) for i in eachindex(a.data))
end

@testset "(h) JLD2 round trips" begin
    meta = ovro_metadata(hcat(INP["offsets"]...), [40e6, 60e6])
    for pol in (TTCal.Full, TTCal.Dual)
        @testset "Dataset $(string(nameof_(pol)))" begin
            ds = genvis(meta, TTCal.ConstantBeam(), test_sky(), polarization=pol)
            ds.data[1, 1].flags[2][1] = true   # exercise a flag
            path = tempname() * ".jld2"
            TTCal.write(path, ds)
            ds2 = TTCal.Dataset(path)
            @test same_dataset(ds, ds2)
            rm(path)
        end
        @testset "Calibration $(string(nameof_(pol))) via write_cal/read_cal" begin
            T = pol == TTCal.Dual ? TTCal.DiagonalJonesMatrix : TTCal.JonesMatrix
            cal = TTCal.Calibration(meta, polarization=pol)
            for f = 1:2, a = 1:5
                cal[f, 1][a] = mkjones(T, INP["gains_"*string(nameof_(pol))][f][a])
            end
            prefix = tempname()
            TTCal.write_cal(prefix, cal)
            @test same_calibration(cal, TTCal.read_cal(prefix))
            rm(prefix * ".jld2")
        end
        @testset "Calibration $(string(nameof_(pol))) via jldopen" begin
            cal = TTCal.Calibration(meta, polarization=pol)
            path = tempname() * ".jld2"
            jldopen(path, "w") do file
                file["calibration"] = cal
            end
            cal2 = jldopen(path, "r") do file
                file["calibration"]
            end
            @test same_calibration(cal, cal2)
            rm(path)
        end
    end
end
