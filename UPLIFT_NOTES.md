# TTCal.jl — Julia 0.6.4 → 1.13.1 uplift notes

Branch `julia-1.13` (from `trunk` 139aa82). Same-stack uplift: structure, names and
algorithms preserved; only the deltas forced by the runtime were changed. Supporting
artifacts: `docs/uplift/BASELINE.md` (0.6 oracle), `docs/uplift/DELTA_CATALOG.md`,
`docs/uplift/PLAYBOOK.md` (the proven recipe, written for the BPJSpec.jl port).

## Dependency change: CasaCore.jl → CasaCoreCompat.jl

Michael Eastwood's `CasaCore.jl` (the API this code was written against) is unregistered,
unmaintained, and its Julia 1.x fork's binaries do not load on 1.13 (missing `libgsl.so.27`).
The maintained library is JuliaAstro `Casacore.jl` (CxxWrap), whose API is different and whose
measure types are mutable C++ handles. To keep TTCal's ~250 call sites and its plain `isbits`
measure types (which the hot loops in `genvis` and the calibration core depend on), a workspace
package **`../CasaCoreCompat.jl`** re-creates the old `Measures`/`Tables` API on top of
`Casacore.jl`. TTCal's only change is `using CasaCore.X` → `using CasaCoreCompat.X` plus the
`Project.toml` dependency (`[sources]` path, so the workspace layout `../CasaCoreCompat.jl` and
`../Casacore.jl` is required). `Casacore.jl` must be built once (`Pkg.build("Casacore")`
downloads the ephemeris data). Frame conversions agree with the 0.6 package to 2e-16.

## Delta → fix mapping (all hand-applied; no codemod exists for Julia 0.6→1.x)

| Catalog ID | Delta | Fix | Files |
|---|---|---|---|
| 001 | REQUIRE → Project.toml, undeclared DocOpt | Project.toml with `[compat]`, `[sources]`, Test extra; stale 1.0 Manifest regenerated | Project.toml, Manifest.toml |
| 002 | LinearAlgebra/Statistics/Random stdlibs; `Base.det/inv/kron/transpose/rand!` ownership | `using` lines; methods defined on `LinearAlgebra.*`, `Random.rand!` | src/TTCal.jl, math/jones.jl, data/datasets.jl |
| 003 | `ctranspose` → `adjoint` (Jones types would fall back to lazy `Adjoint`) | `LinearAlgebra.adjoint` methods (dead local `ctranspose` defs left in place) | math/jones.jl |
| 004 | `doc"""` | `@doc doc"""` (Markdown.@doc_str) | math/*, sky/spectra.jl, instrument/* |
| 005 | `immutable`/`type` | `struct`/`mutable struct` | math/stokes.jl, utm.jl, ionosphere.jl |
| 006 | `Complex128`/`Complex64` | `ComplexF64`/`ComplexF32` | jones.jl, calibration.jl, transform.jl, datasets.jl, commandline.jl, genvis.jl, struct-of-arrays.jl |
| 007 | `x? a : b` | space before `?` | commandline.jl, utm.jl |
| 008 | `Array{T}(dims)` | `Array{T}(undef, dims)` | datasets.jl, calibration.jl, test/setup.jl |
| 009 | `warn`, `srand`, `Base.Test` | `@warn`, `Random.seed!`, `Test` | calibration.jl, test/runtests.jl |
| 014 | CasaCore dependency | CasaCoreCompat (above) | src/TTCal.jl, test/runtests.jl |
| 021 | tests/docs/CI pinned to 0.6; `vecnorm`, `linspace` in non-included tests | `norm`, `range(...; stop, length)`, `.travis.yml` 1.13, Documenter kwargs removed | test/*, docs/make.jl, .travis.yml |
| new | `'` returns lazy `Adjoint`, not accepted by table column write | `Matrix([x y z]')` | test/setup.jl |
| new | JSON 1.x returns `JSON.Object` | `JSON.parsefile(...; dicttype=Dict)` | test/characterization.jl |
| new | RNG stream changed (MersenneTwister → Xoshiro): random antenna positions put the test source below the horizon | deterministic fixture at OVRO with a source derived from the geometry; assertions unchanged | test/data/rotate-phase-center.jl |

## Dual-run proof (true dual run: both runtimes executed here)

| Suite | Julia 0.6.4 (oracle) | Julia 1.13.1 |
|---|---|---|
| `test/runtests.jl` original testsets | 147 pass / 147 | 147 pass / 147 |
| `test/characterization.jl` golden values recorded on 0.6 (Jones algebra, norms, Runge–Kutta, PowerLaw, delays/fringes, genvis, StefCal gains, fitvis, frame conversions) | 129 pass / 129 (self-consistency) | 129 pass / 129 |
| JLD2 write→read round trips (Dataset, Calibration) | 6 / 6 | 6 / 6 |
| `Pkg.test()` total on 1.13 (runtests now includes characterization) | — | 282 pass / 282 |
| CasaCoreCompat own suite (ported from the original CasaCore.jl tests + compat checks) | — | 856 pass / 856 |

Result deltas adjudicated:
- **Intended behaviour change — `norm` of Jones matrices/vectors.** On 0.6, `norm` of an
  `AbstractMatrix` subtype was the spectral 2-norm per element; 1.x uses the Frobenius norm.
  StefCal's convergence test in `solve!` uses this norm, so per-channel iteration counts shift by
  ~1 (golden `[30,24]` → `[29,24]`); solved gains agree to < 1e-6. Accepted: standard, cheaper
  (no 2×2 eigen-decomposition per element), and the 0.6 behaviour was accidental. The golden test
  compares `norm` against the recorded Frobenius/l2 values on 1.x and iteration counts within ±3.
- **genvis visibilities differ by ≤ 4e-10 relative** (sum of |V|² agrees to 3e-11): the
  J2000→ITRF conversion differs by ~4e-12 rad between casacore 3.5 (0.6 build) and
  `casacore_jll` 3.7.1; baseline phase amplifies it. Compared at 1e-8 instead of 1e-10.
- Everything else reproduces the 0.6 oracle within 1e-10 relative (frames within 1e-8 rad).

## Residual items (not changed in this pass)
- Latent bugs that exist on 0.6 too: `calibrate_onefrequency_onetime!` references an undefined
  `prg` when `quiet=false`; `test/peel.jl` (not included in runtests) calls `Tables.lock/unlock`
  (a no-op in CasaCoreCompat).
- `docs/make.jl` still uses `format = :html`/`html_prettyurls`, removed in current Documenter;
  `.travis.yml` coverage step uses `Pkg.dir`. Neither is exercised.
- Non-included files (`src/utm.jl`, `src/ionosphere.jl`, `src/subsrc.jl`, `src/sky/skymodels.jl`
  and their tests) were updated syntactically and parse on 1.13, but were never executed.
- `.jld2` files written on Julia 0.6 are not expected to load (Unitful/CasaCore type layouts
  changed); regenerate them.
- Upstream PR candidates for JuliaAstro Casacore.jl: julia compat bound ≥ 1.13; `long`/`lat` for
  `Direction`; typed `TableRecord` keyword bindings in casacorecxx (would let CasaCoreCompat drop
  its TaQL-based keyword layer).

## Deferred modernisation (deliberately not done, to keep the diff reviewable)
No renames, no reformatting, no idiom updates beyond removed APIs, no fixing of the latent bugs
above, no GPU/array-type parametrisation of the struct-of-arrays containers (planned as a later
phase gated by this same test suite), no `Converter` reuse inside TTCal (CasaCoreCompat already
caches converters per `ReferenceFrame`, ~11× faster repeated conversions).

## Resolved dependency versions (2026-10-05)
CasaCoreCompat 0.1.0 (path) → Casacore 0.4.1 (path) → casacore_jll 3.7.1; DocOpt 0.5.0,
FileIO 1.20.0, JLD2 0.6.7, JSON 1.10.0, NLopt 1.2.1, ProgressMeter 1.11.0, StaticArrays 1.9.22,
Unitful 1.29.0, UnitfulAstro 1.2.2.
