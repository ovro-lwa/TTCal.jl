# Shared by generate.jl (Julia 0.6, writes golden-0.6.json) and ../characterization.jl
# (any version, compares against it). Written to parse on Julia 0.6.4 and 1.x.
# Callers must already have run:
#   using TTCal, CasaCore.Measures, CasaCore.Tables, Unitful, UnitfulAstro, JSON, JLD2

if VERSION < v"0.7"
    using Base.Test
    const CF64 = Complex128
    seed!(n) = srand(n)
    l2norm(x) = sqrt(sum(abs2, x))
else
    using Test, LinearAlgebra, Random
    const CF64 = ComplexF64
    seed!(n) = Random.seed!(n)
    l2norm(x) = sqrt(sum(abs2, x))
end

# ---- flattening of results into plain Float64 lists ---------------------------------------
flat!(out, x::Complex) = (push!(out, Float64(real(x))); push!(out, Float64(imag(x))); out)
flat!(out, x::Real) = (push!(out, Float64(x)); out)
flat!(out, x::Unitful.Quantity) = flat!(out, ustrip(x))
function flat!(out, x::TTCal.AbstractJonesMatrix)
    for f in fieldnames(typeof(x))
        flat!(out, getfield(x, f))
    end
    out
end
function flat!(out, x::AbstractArray)
    for e in x
        flat!(out, e)
    end
    out
end
flat(x) = flat!(Float64[], x)
tryflat(f) = try flat(f()) catch; "ERROR" end   # pins "this errors" as behaviour too
tname(x) = string(typeof(x))
rad(x) = Float64(ustrip(uconvert(u"rad", x)))

const JTYPES = (TTCal.JonesMatrix, TTCal.DiagonalJonesMatrix, TTCal.HermitianJonesMatrix)
mkjones(::Type{TTCal.JonesMatrix}, v) =
    TTCal.JonesMatrix(complex(v[1],v[2]), complex(v[3],v[4]), complex(v[5],v[6]), complex(v[7],v[8]))
mkjones(::Type{TTCal.DiagonalJonesMatrix}, v) =
    TTCal.DiagonalJonesMatrix(complex(v[1],v[2]), complex(v[3],v[4]))
mkjones(::Type{TTCal.HermitianJonesMatrix}, v) =
    TTCal.HermitianJonesMatrix(v[1], complex(v[2],v[3]), v[4])

# ---- shared fixtures ----------------------------------------------------------------------
const OVRO_T = (2015. - 1858.) * 365. * 24. * 60. * 60. * u"s"   # as test/setup.jl createms
function ovro_frame()
    frame = ReferenceFrame()
    OVRO  = Position(pos"WGS84", 1207.969*u"m", -118.284441*u"°", 37.232271*u"°")
    pos   = measure(frame, OVRO, pos"ITRF")
    set!(frame, Epoch(epoch"UTC", OVRO_T))
    set!(frame, pos)
    frame, pos
end

"Metadata like createms(Nant, Nfreq) but built directly (no MS); `off` = 3 x Nant offsets in m."
function ovro_metadata(off, freqs_hz)
    frame, pos = ovro_frame()
    Nant = size(off, 2)
    positions = [Position(pos"ITRF", pos.x+off[1,i], pos.y+off[2,i], pos.z+off[3,i]) for i = 1:Nant]
    zenith = Direction(dir"AZEL", 0*u"°", 90*u"°")
    phase  = measure(frame, zenith, dir"J2000")
    TTCal.Metadata([f*u"Hz" for f in freqs_hz], [Epoch(epoch"UTC", OVRO_T)], positions, [phase])
end

function test_sky()
    TTCal.SkyModel([
        TTCal.Source("A", TTCal.Point(Direction(dir"AZEL", 10*u"°", 30*u"°"),
                     TTCal.PowerLaw(5, 0.5, 0.25, 0.125, 50*u"MHz", [-0.7, 0.1]))),
        TTCal.Source("B", TTCal.Point(Direction(dir"AZEL", 200*u"°", 60*u"°"),
                     TTCal.PowerLaw(3, 0, 0, 0, 50*u"MHz", [-0.5])))])
end

# ---- inputs (random; generated once on 0.6, stored in the JSON) ---------------------------
function make_inputs()
    seed!(123)
    inp = Dict{String,Any}()
    for T in JTYPES
        n = string(nameof_(T))
        inp["jones_"*n] = [flat(rand(T)) for k = 1:2]
    end
    inp["jonesvec"] = [flat(rand(TTCal.JonesMatrix)) for k = 1:6]
    inp["rk_x0"] = rand(2)
    inp["offsets"] = 100 .* randn(3, 5)'  # 5 x 3 (row per antenna)
    inp["offsets"] = [inp["offsets"][i,:] for i = 1:5]
    inp["fitvis_pos"] = [100 .* randn(3) for k = 1:10]
    inp["fitvis_dd"] = randn(2)    # arcminutes
    inp["gains_Dual"] = [[flat(DiagonalJonesMatrix_(0.2)) for a = 1:5] for f = 1:2]
    inp["gains_Full"] = [[flat(JonesMatrix_(0.2)) for a = 1:5] for f = 1:2]
    inp
end
nameof_(T) = T.name.name
DiagonalJonesMatrix_(s) = TTCal.DiagonalJonesMatrix(1 + s*(rand(CF64) - 0.5), 1 + s*(rand(CF64) - 0.5))
JonesMatrix_(s) = TTCal.JonesMatrix(1 + s*(rand(CF64) - 0.5), 0.25s*(rand(CF64) - 0.5),
                                    0.25s*(rand(CF64) - 0.5), 1 + s*(rand(CF64) - 0.5))

# ---- (a) Jones algebra --------------------------------------------------------------------
function golden_jones(inp)
    out = Dict{String,Any}()
    for T in JTYPES
        n = string(nameof_(T))
        J1, J2 = [mkjones(T, v) for v in inp["jones_"*n]]
        d = Dict{String,Any}()
        d["J1"] = flat(J1); d["J2"] = flat(J2)
        d["adjoint_type"]   = tname(J1');  d["adjoint"]   = flat(J1')
        d["transpose_type"] = tname(transpose(J1)); d["transpose"] = flat(transpose(J1))
        d["conj_type"] = tname(conj(J1)); d["conj"] = flat(conj(J1))
        d["inv_type"] = tname(inv(J1)); d["inv"] = flat(inv(J1))
        d["det"] = flat(det(J1))
        d["mul_type"] = tname(J1*J2); d["mul"] = flat(J1*J2)
        d["norm"] = tryflat(() -> norm(J1))          # 0.6: matrix 2-norm; 1.x: Frobenius
        d["frobenius"] = Float64(sqrt(sum([abs2(x) for x in J1])))
        d["kron"] = tryflat(() -> kron(J1, J2))
        out[n] = d
    end
    H = mkjones(TTCal.HermitianJonesMatrix, inp["jones_HermitianJonesMatrix"][1])
    J = mkjones(TTCal.JonesMatrix, inp["jones_JonesMatrix"][2])
    out["mixed"] = Dict{String,Any}(
        "herm_times_jones_type" => tname(H*J), "herm_times_jones" => flat(H*J),
        "jones_times_herm_type" => tname(J*H), "jones_times_herm" => flat(J*H),
        "congruence_type" => tname(TTCal.congruence_transform(J, H)),
        "congruence" => flat(TTCal.congruence_transform(J, H)))
    out
end

# ---- (b) norms and Runge-Kutta ------------------------------------------------------------
function golden_norms_rk(inp)
    out = Dict{String,Any}()
    jm = [mkjones(TTCal.JonesMatrix, v) for v in inp["jonesvec"]]
    out["norm_vector_jonesmatrix"] = tryflat(() -> norm(jm))
    out["l2_vector_jonesmatrix"] = l2norm(flat(jm))
    jv = TTCal.JonesVector(6);         for i = 1:6; jv[i] = jm[i]; end
    dv = TTCal.DiagonalJonesVector(6); for i = 1:6; dv[i] = TTCal.DiagonalJonesMatrix(jm[i].xx, jm[i].yy); end
    cv = TTCal.ComplexVector(6);       for i = 1:6; cv[i] = jm[i].xy; end
    for (n, v) in (("JonesVector", jv), ("DiagonalJonesVector", dv), ("ComplexVector", cv))
        out["norm_"*n] = tryflat(() -> norm(v))
        out["l2_"*n] = l2norm(flat(v))
        out["norm_diff_"*n] = tryflat(() -> norm(v - 2*v))
        out["eltype_"*n] = string(eltype(v))
    end
    # RK steps on dx/dt = A x with A = [0 -0.1; 0.1 -0.05]; step length is baked into f!
    f!(k, x) = (k[1] = -0.1*x[2]; k[2] = 0.1*x[1] - 0.05*x[2]; k)
    x0 = Vector{Float64}(inp["rk_x0"])
    ws = TTCal.RKWorkspace(x0, 4)
    x = copy(x0); xs = Any[]
    for it = 1:5
        x = TTCal.rk4!(ws, f!, x); push!(xs, copy(x))
    end
    out["rk4_5steps"] = flat(xs)
    out["rk2_1step"] = flat(TTCal.rk2!(TTCal.RKWorkspace(x0, 2), f!, x0))
    out
end

# ---- (c) PowerLaw -------------------------------------------------------------------------
function golden_spectrum()
    out = Dict{String,Any}()
    pl  = TTCal.PowerLaw(1.5, 0.5, 0.25, 0.125, 100*u"MHz", [-0.5, 0.1])
    neg = TTCal.PowerLaw(-2.0, 0.0, 0.0, 0.0, 74*u"MHz", [0.3])
    zer = TTCal.PowerLaw(0, 0, 0, 0, 74*u"MHz", [0.3])
    hz  = [50e6, 74.3e6, 100e6, 150e6]
    out["freqs_hz"] = hz
    out["powerlaw_Hz"]  = tryflat(() -> [pl(f*u"Hz") for f in hz])
    out["powerlaw_MHz"] = tryflat(() -> [pl(f/1e6*u"MHz") for f in hz])
    out["negative_I_Hz"]  = tryflat(() -> [neg(f*u"Hz") for f in hz])
    out["negative_I_MHz"] = tryflat(() -> [neg(f/1e6*u"MHz") for f in hz])
    out["zero_I"] = tryflat(() -> [zer(f*u"Hz") for f in hz])
    out["scaled"] = tryflat(() -> [(2*pl)(f*u"Hz") for f in hz])
    out["stokes_type"] = tname(pl(50u"MHz"))
    out
end

# ---- (d) delays / fringes -----------------------------------------------------------------
function golden_delays(inp)
    out = Dict{String,Any}()
    frame, pos = ovro_frame()
    positions = [Position(pos"ITRF", pos.x+o[1], pos.y+o[2], pos.z+o[3]) for o in inp["offsets"]]
    src = Direction(dir"ITRF", 0.3*u"rad", 0.7*u"rad")
    pc  = Direction(dir"ITRF", 0.31*u"rad", 0.69*u"rad")
    delays = TTCal.geometric_delays(positions, src, pc)
    out["far_delays_s"] = flat(delays)
    out["fringes_50MHz"] = flat(TTCal.delays_to_fringes(delays, 50e6*u"Hz"))
    out["fringes_50MHz_unit"] = flat(TTCal.delays_to_fringes(delays, 50*u"MHz"))
    npos = Position(pos"ITRF", 1e5*cos(0.3)*cos(0.7), 1e5*sin(0.3)*cos(0.7), 1e5*sin(0.7))
    out["near_delays_s"] = tryflat(() -> TTCal.geometric_delays(positions, npos, pc))
    out
end

# ---- (e) genvis ---------------------------------------------------------------------------
function golden_genvis(inp)
    out = Dict{String,Any}()
    off = hcat(inp["offsets"]...)
    meta = ovro_metadata(off, [40e6, 60e6])
    ds = genvis(meta, TTCal.ConstantBeam(), test_sky(), polarization=TTCal.Full)
    N = TTCal.Nant(ds)
    pairs = [(a1, a2) for a1 = 1:N for a2 = a1:N][1:8]   # first 8 baselines, canonical order
    out["pairs"] = [[p[1], p[2]] for p in pairs]
    out["vis_first8"] = [flat([ds[f, 1][p[1], p[2]] for p in pairs]) for f = 1:2]
    out["sum_abs2"] = Float64(sum(f -> sum(abs2, flat(ds.data[f, 1].data)), 1:2))
    dd = genvis(meta, TTCal.ConstantBeam(), test_sky(), polarization=TTCal.Dual)
    out["dual_vis_first8"] = [flat([dd[f, 1][p[1], p[2]] for p in pairs]) for f = 1:2]
    out["dual_sum_abs2"] = Float64(sum(f -> sum(abs2, flat(dd.data[f, 1].data)), 1:2))
    out
end

# ---- (f) calibrate ------------------------------------------------------------------------
function iteration_count(data, model, pol, Nant, tol, maxiter)
    # replicates TTCal.calibrate_onetime! so we can see how many RK4 iterations were needed
    out = Int[]
    for f = 1:TTCal.Nfreq(data)
        ds = [getindex.( data[f, :], a) for a = 1:Nant]
        ms = [getindex.(model[f, :], a) for a = 1:Nant]
        n = maxiter + 1
        for k = 1:maxiter
            g = TTCal.Solution(pol, Nant).data
            if TTCal.solve!(g, ds, ms, k, tol)
                n = k; break
            end
        end
        push!(out, n)   # maxiter+1 means "did not converge"
    end
    out
end

function golden_calibrate(inp)
    out = Dict{String,Any}()
    meta = ovro_metadata(hcat(inp["offsets"]...), [40e6, 60e6])
    beam = TTCal.ConstantBeam()
    sky  = test_sky()
    for (pol, name) in ((TTCal.Dual, "Dual"), (TTCal.Full, "Full"))
        T = name == "Dual" ? TTCal.DiagonalJonesMatrix : TTCal.JonesMatrix
        truth = TTCal.Calibration(meta, polarization=pol)
        for f = 1:2, a = 1:5
            truth[f, 1][a] = mkjones(T, inp["gains_"*name][f][a])
        end
        model = genvis(meta, beam, sky, polarization=pol)
        data  = TTCal.corrupt(model, truth)
        tol, maxiter = 1e-8, 400
        cal = calibrate(deepcopy(data), sky, beam, tolerance=tol, maxiter=maxiter, minuvw=0.0, quiet=true)
        d = Dict{String,Any}()
        d["true_gains"] = [flat([truth[f, 1][a] for a = 1:5]) for f = 1:2]
        d["gains"] = [flat([cal[f, 1][a] for a = 1:5]) for f = 1:2]
        # same flagging that calibrate applies (minuvw=0 flags nothing); the model is corrupt-free
        d["iterations"] = tryint(() -> iteration_count(data, model, pol, 5, tol, maxiter))
        d["converged"] = d["iterations"] isa Vector && all(i -> i <= maxiter, d["iterations"])
        out[name] = d
    end
    out
end
tryint(f) = try f() catch; "ERROR" end

# ---- (g) fitvis ---------------------------------------------------------------------------
function golden_fitvis(inp)
    out = Dict{String,Any}()
    positions = [Position(pos"ITRF", p[1], p[2], p[3]) for p in inp["fitvis_pos"]]
    metadata = TTCal.Metadata([50.0u"MHz", 74.3u"MHz", 93.1u"MHz"],
                              [Epoch(epoch"UTC", (2017-1858)*u"yr")],
                              positions, [Direction(dir"AZEL", 0u"°", 90u"°")])
    spectrum = TTCal.PowerLaw(1, 0, 0, 0, 100u"MHz", [-0.5])
    j2000 = measure(ReferenceFrame(metadata), Direction(dir"AZEL", 10u"°", 30u"°"), dir"J2000")
    ra, dec = longitude(j2000), latitude(j2000)
    δra  = uconvert(u"rad", inp["fitvis_dd"][1]*u"arcminute")
    δdec = uconvert(u"rad", inp["fitvis_dd"][2]*u"arcminute")
    j2000′ = Direction(dir"J2000", ra+δra, dec+δdec)
    a = deg2rad(500/3600); b = deg2rad(300/3600); c = deg2rad(50)
    for (name, mk) in (("point",    d -> TTCal.Point(d, spectrum)),
                       ("gaussian", d -> TTCal.Gaussian(d, spectrum, a, b, c)))
        before = TTCal.Source("A", mk(j2000))
        after  = TTCal.Source("B", mk(j2000′))
        data = genvis(metadata, TTCal.ConstantBeam(), after, polarization=TTCal.Dual)
        fit  = fitvis(data, before, tolerance=eps(Float64))
        d = fit.shapes[1].direction
        out[name] = Dict{String,Any}("fit_lon_lat_rad" => [rad(longitude(d)), rad(latitude(d))],
                                     "true_lon_lat_rad" => [rad(longitude(j2000′)), rad(latitude(j2000′))],
                                     "start_lon_lat_rad" => [rad(ra), rad(dec)])
    end
    out
end

# ---- (i) frame conversions ----------------------------------------------------------------
function golden_frames()
    out = Dict{String,Any}()
    frame, pos = ovro_frame()
    out["ovro_itrf_m"] = [pos.x, pos.y, pos.z]
    for (name, az, el) in (("zenith", 0.0, 90.0), ("az10_el30", 10.0, 30.0), ("az200_el60", 200.0, 60.0))
        d = Direction(dir"AZEL", az*u"°", el*u"°")
        for (sys, tag) in ((dir"J2000", "J2000"), (dir"ITRF", "ITRF"))
            m = measure(frame, d, sys)
            out[name*"_"*tag] = [rad(longitude(m)), rad(latitude(m))]
        end
    end
    out
end

function golden_all(inp)
    Dict{String,Any}("jones" => golden_jones(inp), "norms_rk" => golden_norms_rk(inp),
                     "spectrum" => golden_spectrum(), "delays" => golden_delays(inp),
                     "genvis" => golden_genvis(inp), "calibrate" => golden_calibrate(inp),
                     "fitvis" => golden_fitvis(inp), "frames" => golden_frames())
end
