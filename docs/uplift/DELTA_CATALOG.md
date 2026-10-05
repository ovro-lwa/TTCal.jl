# DELTA_CATALOG — TTCal.jl, Julia 0.6.4 → 1.13.1 (condensed)

Source: static analysis of trunk (139aa82) by the version-delta analyst, plus
architect review. No ecosystem codemod exists for Julia 0.6→1.x (the 0.7
deprecation pass is the only tool, and no 0.7 runtime is available); all
findings are from reading. Working branch `julia-1.13` already contains the
`origin/updatev1` merge, which resolves the items marked [done-by-updatev1].

## Ranked by blast radius

| ID | Category | What | Live sites | Class | Status on julia-1.13 |
|---|---|---|---|---|---|
| 001 | Project-system | REQUIRE → Project.toml (+DocOpt, stdlibs LinearAlgebra/Statistics/Random/Markdown, Test extra, [compat]) | pkg | Mechanical | partial: Project.toml exists but CasaCore UUID may be wrong (f971ce14… vs registry 718368f3…), stale 1.0-era Manifest.toml, no [compat] |
| 002 | API-removed | LinearAlgebra/Statistics/Random now stdlibs; `Base.det/inv/kron/transpose/rand!` method ownership | ~25 | Mechanical | [done-by-updatev1] except verify `Base.rand(::Type{JonesMatrix})` still dispatches (Random.rand) |
| 003 | Behavioral-silent | `ctranspose` → `adjoint`; `J'` on Jones types falls back to lazy `Adjoint` wrapper otherwise | 3 defs + ~6 uses (calibration.jl:512,539-546,~715; getspec.jl:73; visibilities.jl:50) | Mechanical but silent | [done-by-updatev1]: `LinearAlgebra.adjoint` defined; leftover dead local `ctranspose` defs. TEST: `J' isa JonesMatrix`, `(AB)' ≈ B'A'` |
| 004 | API-removed | `doc"""` → `@doc doc"""` (Markdown.@doc_str) | 12 | Mechanical | [done-by-updatev1] live; `src/ionosphere.jl:77` dead |
| 005 | API-removed | `immutable`/`type` keywords | 1 live | Mechanical | [done-by-updatev1] stokes.jl; dead: utm.jl:16, ionosphere.jl:16 |
| 006 | API-removed | `Complex128`→`ComplexF64`, `Complex64`→`ComplexF32` | ~35 | Mechanical | remaining: data/transform.jl:74,76 (Complex128); commandline.jl:153,223 and data/datasets.jl:169 (Complex64) |
| 007 | API-removed | `x? a : b` needs space before `?` | 6 | Mechanical | [done-by-updatev1] live; dead utm.jl:43,93 |
| 008 | API-removed | `Array{T}(dims)` → `Array{T}(undef, dims)` | src 4, test 5 | Mechanical | remaining: data/datasets.jl:57,62; check calibration.jl `Array{Solution{P,T}}(...)` |
| 009 | API-removed | `warn`→`@warn`, `ascii(...)` removed?, `srand`→`Random.seed!`, `Base.Test`→`Test` | ~8 | Mechanical | remaining: commandline.jl:101 `ascii(` (still exists in 1.x as `ascii(::String)`; keep or drop) |
| 010 | Behavioral-silent | `@eval` loops / macro hygiene / soft scope in commandline.jl | — | verify by running | — |
| 011 | Behavioral-silent | custom AbstractArray subtypes (ComplexVector, JonesVector, DiagonalJonesVector, StokesVector, Solution, AbstractJonesMatrix) under 1.x broadcast/`similar`/`norm` semantics; rungekutta.jl `@.` workspace; calibration.jl:177-180 `norm(gains-newgains)/norm(gains)` | ~15 | Judgment | TEST: solve! convergence/iteration count unchanged vs 0.6; `norm` of Vector{JonesMatrix} = Frobenius-of-elements |
| 012 | Behavioral-silent | local `checkbounds` shadowing Base; `show` formatting of 2x2 types | few | low | — |
| 013 | Behavioral-silent | module-local `write`, `merge!`, `position` shadowing Base | few | low | TEST: `TTCal.write(path, dataset)` round-trip |
| 014 | Dependency | CasaCore 0.2.2 (user fork, 0.6) → 0.3.x (registry, BinaryBuilder casacorewrapper_jll). Exports identical; Tables API signatures identical (`open(path; write)`, `create`, `close`, `delete`, `add_rows!`, `column_exists`, `getindex/setindex!` by String and `kw""`) | ~40 | Judgment (integration) | verify element types/shapes of `ms["DATA"]`, ComplexF32 write-back, Measures `norm/dot/cross` via LinearAlgebra |
| 015 | Dependency | Unitful 0.x → 1.x: `u"c"` still exists; Quantity type params changed (affects struct field types `typeof(1.0*u"Hz")`, JLD2 files) | ~12 | mostly Mechanical | TEST: PowerLaw(ν) in Hz vs MHz; geometric_delays/delays_to_fringes |
| 016 | Dependency | JLD2 0.0.6 → 0.5+: positional `jldopen(f, wr, create, truncate, IOStream)` in commandline.jl:282,288 may be gone; 0.6-written .jld2 files NOT portable (type layouts changed) | 4 | Judgment | TEST: write→read round trip of Dataset and Calibration on 1.13 |
| 017 | Dependency | NLopt: `Opt(:LN_SBPLX,2)`, `max_objective!`, bounds, `ftol_abs!`, `optimize` unchanged; libnlopt newer → last-digit drift | 1 fn | Mechanical | TEST: fitvis within tolerance |
| 018 | Dependency | StaticArrays `@SMatrix/@SVector` ok; `LinearAlgebra.kron` [done]; possible `*` ambiguity with StaticArrays; JSON/ProgressMeter/FileIO unchanged | few | Mechanical | latent 0.6 bug: calibrate_onefrequency_onetime! uses undefined `prg` when quiet=false |
| 019 | Dependency | DocOpt never in REQUIRE; `docopt(doc, args, version=...)` unchanged | 2 | Mechanical | [done-by-updatev1] in Project.toml |
| 020 | Behavioral-silent | `@eval`/`@evalpoly` generated code in beams.jl, jones.jl, stokes.jl | — | none expected | — |
| 021 | Project-system | tests: `using Test/Random/LinearAlgebra/Statistics`, `Random.seed!`, `undef`, `ComplexF64`; `vecnorm`→`norm` in NON-included tests (peel.jl, rungekutta.jl, skymodels.jl `linspace`); docs/make.jl, .travis.yml pin 0.6 | ~50 | Mechanical | live test files [done-by-updatev1]; dead test files + CI/docs remain |

## Not applicable (zero live hits)
Void, Nullable, linspace (live), find, ind2sub/sub2ind, indices, endof, start/next/done,
`.'`, A_mul_B!, eye, expm, eig, svd, squeeze, countnz, readstring, STDOUT, isleaftype,
@pure, Pkg.dir, contains/search/ismatch, @parallel, Threads, Dates, Mmap, Libdl, Compat.

## upliftVsRewriteSignal
Uplift. Live code is already struct/where/dot-broadcast era. Expected diff: a few
hundred lines + Project.toml. Judgment concentrated in 003/011/016 and dependency
integration (014/015).

## Test-before-touch (silent-behavioral) — characterize on 1.13 against the 0.6 oracle
1. 003 adjoint of Jones types: type and values of `J'`, `(AB)' ≈ B'A'`, `J*inv(J) ≈ I`.
2. 011 norm/broadcast/similar on custom vectors; solve! iteration counts.
3. 015 Unitful: PowerLaw, geometric_delays, delays_to_fringes, mean(frequencies).
4. 016 JLD2 round trip Dataset + Calibration.
5. 017 NLopt fitvis within tolerance.
6. 014 CasaCore DATA/FLAG dtype+shape; ComplexF32 write-back.
7. 013 TTCal.write / merge! dispatch to TTCal methods.
