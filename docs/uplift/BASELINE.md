# BASELINE — TTCal.jl on Julia 0.6.4 (source runtime, the oracle)

Run: 2026-10-05, `/home/xhall/software/julia-0.6/bin/julia -O3` with
`CPLUS_INCLUDE_PATH=/opt/include LIBRARY_PATH=/opt/lib LD_LIBRARY_PATH=/opt/lib`,
`include("test/runtests.jl")` from `test/`. Package resolved from
`~/.julia/v0.6/TTCal`, which `diff -rq` confirms is byte-identical to this
checkout at trunk (139aa82).

| Testset (as included by test/runtests.jl) | Result |
|---|---|
| math/special.jl, math/jones.jl, math/stokes.jl | pass |
| data/rotate-phase-center.jl | pass |
| sky/spectra.jl | pass |
| instrument/beams.jl, instrument/genvis.jl | pass |
| getspec.jl, fitvis.jl, calibration.jl | pass |
| **Total** | **147 pass / 147** |

Non-fatal stderr noise: casacore 3.5.0 "Leap second table TAI_UTC seems
out-of-date" (environment, not TTCal).

Not included by runtests.jl on either runtime (not part of the oracle):
math/rungekutta.jl, data/metadata.jl, data/visibilities.jl, sky/skymodels.jl,
utm.jl, ionosphere.jl, subsrc.jl, peel.jl.
