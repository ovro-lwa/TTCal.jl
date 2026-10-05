# Julia 0.6.4 -> 1.13.1 uplift playbook (proven on TTCal.jl; next target: ../BPJSpec.jl)

## Environment facts
- `julia` on PATH = 1.13.1 (juliaup). Julia 0.6 oracle: `/home/xhall/software/julia-0.6/bin/julia`,
  run with `CPLUS_INCLUDE_PATH=/opt/include LIBRARY_PATH=/opt/lib LD_LIBRARY_PATH=/opt/lib`.
  The 0.6 package tree is `~/.julia/v0.6/` (contains TTCal at trunk 139aa82, BPJSpec, CasaCore).
  To run a 0.6 suite without touching it: copy `~/.julia/v0.6/<Pkg>/test` to a scratch dir and run
  `julia-0.6 --color=no runtests.jl` there (this is how you get 0.6 values / RNG draws for evidence).
- casacore: use `CasaCoreCompat` (UUID `ac24a7dd-83c5-45b5-8923-fca2a646bec5`, path `../CasaCoreCompat.jl`),
  submodules `Measures`, `Tables`, same API as old `CasaCore.Measures/Tables`. It pulls `../Casacore.jl`
  (v0.4.1, casacore_jll 3.7.1) via its own `[sources]`.
- `[sources]` requires `julia = "1.11"` compat.
- Resolved versions (Oct 2026): DocOpt 0.5.0, FileIO 1.20.0, JLD2 0.6.7, JSON 1.10.0, NLopt 1.2.1,
  ProgressMeter 1.11.0, StaticArrays 1.9.22, Unitful 1.29.0, UnitfulAstro 1.2.2, Statistics 1.11.5.
- Method overwrites are a hard error during precompilation on 1.10+, so a clean `Pkg.precompile()`
  already proves "no overwrites". Check ambiguities with `Test.detect_ambiguities(Pkg; recursive=false)`.

## Ordered steps
1. Project.toml: replace `CasaCore = "f971ce14-..."` with `CasaCoreCompat = "ac24a7dd-83c5-45b5-8923-fca2a646bec5"`;
   add `[sources] CasaCoreCompat = {path = "../CasaCoreCompat.jl"}`; move `Test` from `[deps]` to
   `[extras]` + `[targets] test = ["Test"]`; `[compat]`: `julia = "1.11"`, every dep major-bounded
   (`CasaCoreCompat = "0.1"`, `JLD2 = "0.6"`, `DocOpt = "0.5"`, `JSON = "1"`, others `"1"`, stdlibs `"1"`).
2. `rm Manifest.toml` then `julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'`.
3. `grep -rn CasaCore` -> `using CasaCoreCompat.Measures` / `using CasaCoreCompat.Tables` in src, test/runtests.jl,
   and any characterization harness. Do NOT edit 0.6-only oracle scripts (e.g. `test/golden/generate.jl`
   which errors unless VERSION < 0.7 and must keep `CasaCore.*`).
4. Grep-and-fix idioms (only where removed): `Complex128`->`ComplexF64`, `Complex64`->`ComplexF32`,
   `Array{T}(dims...)`->`Array{T}(undef, dims...)` (grep `Array{[^}]*}(` without `undef`; TTCal had them
   in `src/calibration.jl` too, not only datasets.jl), `srand`->`Random.seed!`, `linspace`->`range`,
   `Base.Test`->`Test`, `trace`->`tr`, `eye`, `diagm(v)`, scalar+vector `+`->`.+`.
5. `docs/make.jl`: drop `osname`, `deps`, `make` from `deploydocs`.
6. Gate A, then run tests, then fix what the runtime reveals (below).

## Errors hit and fixes (TTCal)
- `MethodError: no method matching write_column!(::Table, ::Adjoint{Float64, Matrix{Float64}}, ::String)`
  at test/setup.jl:61 (`subtable["POSITION"] = [x y z]'`). In 1.x `'` is a lazy `Adjoint`; CasaCoreCompat
  `write_column!` only takes `Array{T}`. Fix: `Matrix([x y z]')`. Grep every `table[...] = <expr>'`.
- `MethodError: no method matching compare_tree(::Dict{String,Any}, ::JSON.Object{String,Any}, ...)`:
  JSON >= 1.0 `parsefile` returns `JSON.Object`, not `Dict`. Fix: `JSON.parsefile(path; dicttype=Dict)`.
- Positional `jldopen(path, wr, create, truncate, IOStream)` STILL works in JLD2 0.6.7 (round-trip tests pass);
  no change needed.
- RNG-stream dependence: `Random.seed!(123)` (Xoshiro) draws differ from 0.6 `srand(123)` (MersenneTwister).
  TTCal `test/data/rotate-phase-center.jl` draws antenna positions with `100randn()` around the geocentre;
  with 1.x draws the test source is at el = -18.9 deg (0.6: +13.6 deg), `genvis` returns zeros, 18 tests fail.
  Not a port bug (code verified correct with an above-horizon draw). Escalate; do not change the seed silently.
  Expect the same class of failure in BPJSpec wherever test outcomes depend on random draws.
- Approved behaviour change: `norm` of Jones matrices is Frobenius on 1.x (0.6: spectral 2-norm). Goldens
  that pin `norm` directly will mismatch (verified: golden == `opnorm(Matrix(J))`); StefCal iteration counts
  shift by ~1 (compare within +-3).
- `string(typeof(x))` prints `ComplexF64` on 1.x vs `Complex{Float64}` on 0.6: type-name goldens need alias-aware comparison.
- Frame-dependent outputs (genvis visibilities) differ from 0.6 at ~4e-10 relative (casacore 3.7.1 vs old
  ephemeris/IERS); compare them at frame tolerance, not 1e-10.

### Resolutions applied (architect decisions, TTCal)
- rotate-phase-center fixture (RESOLVED): replaced `100randn()` geocentric antennas with OVRO ITRF
  (`measure(ReferenceFrame(), Position(pos"WGS84", 1207.969u"m", -118.284441u"°", 37.232271u"°"), pos"ITRF")`)
  plus fixed ~100 m offsets; source direction derived from the geometry,
  `measure(ReferenceFrame(metadata), Direction(dir"AZEL", 30u"°", 60u"°"), dir"J2000")`, used for both the
  Source and `rotate_phase_center!`. Assertions untouched. Pattern for BPJSpec: replace RNG-dependent
  geometry with deterministic physical geometry; never just pick a lucky seed.
- Characterization norm goldens: on VERSION >= v"0.7" compare `norm(J)` against the recorded `frobenius`
  entry and `norm_*`/`norm_diff_*` against `l2_*` (helper `norm_golden`); 0.6 still compares `norm`.
  golden-0.6.json is not edited.
- Type-name goldens: normalise `Complex{Float64}`->`ComplexF64`, `Complex{Float32}`->`ComplexF32` (helper `normtype`).
- genvis `vis_first8`/`dual_vis_first8`: per-key tolerance TOL_FRAME (1e-8) via `compare_tree(...; keytol=Dict(...))`
  (casacore 3.5 vs 3.7.1 J2000->ITRF differs ~4e-12 rad, amplified by 2πντ to ~4e-10 relative); `sum_abs2` stays TOL_MATH.
- Keep characterization.jl parseable on 0.6 (check: `julia-0.6 -e 'parse(...)'` loop) so the dual-run still works.
- Final: `Pkg.test()` -> 282/282 (147 baseline + 135 characterization).

## Commands that prove a package is done
    julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
    julia --project=. --warn-overwrite=yes -e 'using <Pkg>; using Test; println(length(Test.detect_ambiguities(<Pkg>; recursive=false)))'
    julia --project=. -e 'using Pkg; Pkg.test()'            # compare count to 0.6 baseline
    cd test && julia --project=.. --color=no characterization.jl   # if a golden harness exists
    julia --project=. bin/<cli>.jl --help                     # CLI smoke test, if any
    git diff --stat trunk -- . ':!Manifest.toml'
Note: a failing top-level `@testset` throws and aborts the rest of a script; run later top-level testsets
separately (wrap earlier ones in try/catch in a scratch copy) to see their results.

## Addendum (2026-10-05): lessons from the BPJSpec.jl port
BPJSpec.jl was ported with this recipe; its own `docs/uplift/PLAYBOOK.md` lists 15 new error/fix
entries. The ones most likely to recur in the next package:
- 0.6 `Base.find_in_path` searches `Pkg.dir()` before `LOAD_PATH`: `push!(LOAD_PATH, ...)` does NOT
  make 0.6 load a checkout when the package is installed; `include("<checkout>/src/Pkg.jl")` first.
  After the port the branch's `src/` no longer parses on 0.6, so regenerate goldens from the
  untouched 0.6 source (`git archive <0.6 branch> src`; for BPJSpec that is
  `frequenecy-determined-beam`, i.e. `master` + the frequency-dependent beam).
- Custom broadcasting on non-AbstractArray types needs `broadcastable`/`BroadcastStyle`/`materialize!`
  (typed with your own style), for EVERY type that can be an argument; a missing trait inside a
  `remotecall`ed loop shows up as a silent hang, not an error.
- FastTransforms ≥ 0.17 plans are C pointers: never ship them to workers (segfault); add a
  2-worker test, the single-process suite cannot catch it.
- Unitful 1.x CODATA-2018 constants shift `u"k"` by 3.48e-7: divide the exact ratio out of the
  affected golden keys instead of loosening tolerances.
- Golden fixtures must be well-conditioned and phase-invariant (full-rank generalised
  eigenproblems; `V*W*W'*V'` not `W*W'`), or the dual run fails for reasons unrelated to the port.
