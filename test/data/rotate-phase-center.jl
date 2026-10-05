@testset "rotate-phase-center.jl" begin
    # Deterministic, physical geometry (OVRO + fixed offsets, source at el = 60°) so the result
    # does not depend on the RNG stream (0.6 MersenneTwister vs 1.x Xoshiro draws differ).
    OVRO = measure(ReferenceFrame(), Position(pos"WGS84", 1207.969*u"m", -118.284441*u"°", 37.232271*u"°"), pos"ITRF")
    offsets = [(12.3, -85.1, 47.9), (-96.4, 33.0, -58.2), (71.5, 64.8, -20.6)]
    metadata = TTCal.Metadata([50.0u"MHz", 74.3u"MHz", 93.1u"MHz"],
                              [Epoch(epoch"UTC", (2017-1858)*u"yr")],
                              [Position(pos"ITRF", OVRO.x + dx, OVRO.y + dy, OVRO.z + dz) for (dx, dy, dz) in offsets],
                              [Direction(dir"AZEL", 0u"°", 90u"°")])
    frame = ReferenceFrame(metadata)
    source_direction = measure(frame, Direction(dir"AZEL", 30u"°", 60u"°"), dir"J2000")

    source = TTCal.Source("A thing",
                          TTCal.Point(source_direction,
                                      TTCal.PowerLaw(1, 0, 0, 0, 100u"MHz", [0.0])))
    dataset = genvis(metadata, TTCal.ConstantBeam(), source)
    rotate_phase_center!(dataset, source_direction)

    for frequency = 1:Nfreq(dataset)
        visibilities = dataset[frequency, 1]
        for ant1 = 1:Nant(dataset), ant2 = ant1:Nant(dataset)
            @test visibilities[ant1, ant2] ≈ one(TTCal.JonesMatrix)
        end
    end
end

