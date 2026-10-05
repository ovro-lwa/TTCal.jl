# Characterization (dual-run) tests

`../characterization.jl` compares the current Julia runtime against `golden-0.6.json`, which was
produced by `generate.jl` on Julia 0.6.4 (the oracle). Random inputs are stored *inside* the JSON
(`"inputs"`), so the RNG stream differences between Julia versions do not matter.

Run (from `test/`), on either runtime:

    julia --color=no characterization.jl

Regenerate the golden file (Julia 0.6 only; refuses to run elsewhere):

    cd test && CPLUS_INCLUDE_PATH=/opt/include LIBRARY_PATH=/opt/lib LD_LIBRARY_PATH=/opt/lib \
      /home/xhall/software/julia-0.6/bin/julia --color=no -O3 golden/generate.jl

Add a case: write a `golden_xxx(inp)` function in `compute.jl` returning a `Dict` of plain values
(use `flat(x)` to turn numbers/Jones/arrays into Float64 lists, `tryflat` to pin errors, `tname(x)`
for type names), register it in `golden_all`, regenerate, and add a `compare_tree` testset in
`characterization.jl` with the right tolerance (1e-10 math, 1e-6 optimiser, 1e-8 rad frames).
Tests in section (h) (JLD2 round trips) do not use the golden file.
