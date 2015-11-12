let I0 = 100, Q0 = -50, U0 = 40, V0 = -10, ν0 = 123, index = [1.0]
    spec = Spectrum(I0,Q0,U0,V0,ν0,index)

    frequency = 123.0
    @test norm(spec(frequency) - StokesVector(I0,Q0,U0,V0)) < eps(Float64)
    frequency = 1230.0
    @test norm(spec(frequency) - 10*StokesVector(I0,Q0,U0,V0)) < eps(Float64)
end

let
    frame   = ReferenceFrame()
    sources = [Source("S1",Point("P1",Direction(dir"AZEL",q"0.0deg",q"+45.0deg"),
                           Spectrum(1.0,2.0,3.0,4.0,10e6,[0.0]))),
               Source("S2",Point("P2",Direction(dir"AZEL",q"0.0deg",q"-45.0deg"),
                           Spectrum(1.0,2.0,3.0,4.0,10e6,[0.0])))]
    @test TTCal.isabovehorizon(frame,sources[1]) == true
    @test TTCal.isabovehorizon(frame,sources[2]) == false

    sources′ = TTCal.abovehorizon(frame,sources)
    @test length(sources′) == 1
    @test sources′[1].name == "S1"
end

let
    sources = readsources("sources.json")

    cas_a = sources[1]
    point = cas_a.components[1]
    @test cas_a.name == "Cas A"
    @test point.name == "Cas A"
    dir1 = point.direction
    dir2 = Direction(dir"J2000",q"23h23m24s",q"58d48m54s")
    @test coordinate_system(dir1) === dir"J2000"
    @test longitude(dir1) ≈ longitude(dir2)
    @test  latitude(dir1) ≈  latitude(dir2)
    @test point.spectrum.stokes.I == 555904.26
    @test point.spectrum.stokes.Q == 0
    @test point.spectrum.stokes.U == 0
    @test point.spectrum.stokes.V == 0
    @test point.spectrum.ν0 == 1e6
    @test point.spectrum.spectral_index == [-0.770]

    cyg_a = sources[2]
    point = cyg_a.components[1]
    @test cyg_a.name == "Cyg A"
    @test point.name == "Cyg A"
    dir1 = point.direction
    dir2 = Direction(dir"J2000",q"19h59m28.35663s",q"+40d44m02.0970s")
    @test coordinate_system(dir1) === dir"J2000"
    @test longitude(dir1) ≈ longitude(dir2)
    @test  latitude(dir1) ≈  latitude(dir2)
    @test point.spectrum.stokes.I == 49545.02
    @test point.spectrum.stokes.Q == 0
    @test point.spectrum.stokes.U == 0
    @test point.spectrum.stokes.V == 0
    @test point.spectrum.ν0 == 1e6
    @test point.spectrum.spectral_index == [+0.085,-0.178]
end

#=
let
    sources1 = [PointSource("S1",Direction(dir"J2000",q"1h",q"0d"),
                            1.0,2.0,3.0,4.0,10e6,[0.0]),
                PointSource("S2",Direction(dir"J2000",q"2h",q"0d"),
                            1.0,2.0,3.0,4.0,10e6,[0.0]),
                PointSource("S3",Direction(dir"J2000",q"3h",q"0d"),
                            1.0,2.0,3.0,4.0,10e6,[0.0])]
    filename = tempname()
    writesources(filename,sources1)
    sources2 = readsources(filename)
    for i in eachindex(sources1,sources2)
        @test name(sources1[i]) == name(sources2[i])
        dir1 = direction(sources1[i])
        dir2 = direction(sources2[i])
        @test coordinate_system(dir1) == coordinate_system(dir2)
        @test longitude(dir1) ≈ longitude(dir2)
        @test latitude(dir1) ≈ latitude(dir2)
        @test sources1[i].I == sources2[i].I
        @test sources1[i].Q == sources2[i].Q
        @test sources1[i].U == sources2[i].U
        @test sources1[i].V == sources2[i].V
        @test sources1[i].reffreq == sources2[i].reffreq
        @test sources1[i].index == sources2[i].index
    end
end

let
    source = PointSource("S",Direction(dir"J2000",q"1h",q"0d"),
                         1.0,2.0,3.0,4.0,10e6,[0.0])
    @test name(source) == "S"
    @test repr(source) == "S"
    @test TTCal.flux(source,10e6) == 1.0
    @test TTCal.flux(source,20e6) == 1.0
end

let
    frame = ReferenceFrame()
    t = (2015.-1858.)*365.*24.*60.*60. # a rough, current Julian date (in seconds)
    set!(frame,Epoch(epoch"UTC",Quantity(t,"s")))
    set!(frame,observatory("OVRO_MMA"))
    phase_dir = Direction(dir"J2000",q"19h59m28.35663s",q"+40d44m02.0970s")

    for iteration = 1:5
        l = 2rand()-1
        m = 2rand()-1
        while hypot(l,m) > 1
            l = 2rand()-1
            m = 2rand()-1
        end
        dir = TTCal.lm2dir(phase_dir,l,m)
        l′,m′ = TTCal.dir2lm(phase_dir,dir)
        @test l ≈ l′
        @test m ≈ m′
    end

    # z should be negative in lm2dir
    l,m = (-0.26521340920368575,-0.760596242177856)
    dir = TTCal.lm2dir(phase_dir,l,m)
    l′,m′ = TTCal.dir2lm(phase_dir,dir)
    @test l ≈ l′
    @test m ≈ m′
end

let
    ra = get(q"0h12m34s","deg")
    @test TTCal.format_ra(ra) == "0h12m34.0000s"
    dec = get(q"+0d12m34s","deg")
    @test TTCal.format_dec(dec) == "+0d12m34.0000s"
    dec = get(q"-0d12m34s","deg")
    @test TTCal.format_dec(dec) == "-0d12m34.0000s"
end
=#

