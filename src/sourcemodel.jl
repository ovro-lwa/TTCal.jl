################################################################################
# Source Definitions

abstract AbstractSource

@doc """
These sources have a multi-component power-law spectrum
such that:

    log(S) = log(flux) + index[1]*log(ν/reffreq)
                       + index[2]*log²(ν/reffreq) + ...
""" ->
abstract PowerLawSource

@doc """
These are generic, run-of-the-mill sources that receive
a J2000 position and a power-law spectrum.
""" ->
type Source <: PowerLawSource
    name::ASCIIString
    dir::Direction
    flux::Float64
    reffreq::quantity(Float64,Hertz)
    index::Vector{Float64}
end

Source(name,dir,flux,reffreq,index::Float64) = Source(name,dir,flux,reffreq,[index])

function Source(frame::ReferenceFrame,source::SolarSystemSource)
    dir = measure(frame,Direction(source.name),"J2000")
    Source(source.name,dir,source.flux,source.reffreq,source.index)
end

@doc """
Solar system objects move through the sky and hence their
J2000 position must be calculated for the given epoch.
""" ->
type SolarSystemSource <: PowerLawSource
    name::ASCIIString
    flux::Float64
    reffreq::quantity(Float64,Hertz)
    index::Vector{Float64}
end

@doc """
RFI usually has an unsmooth spectrum and does not rotate
with the sky. Hence these sources are allowed to have any
arbitrary spectrum, and receive an AZEL position.
""" ->
type RFISource <: AbstractSource
    name::ASCIIString
    dir::Direction
    flux::Vector{Float64}
    freq::Vector{quantity(Float64,Hertz)}
end

function RFISource(source::PowerLawSource,frequencies::Vector{quantity(Float64,Hertz)})
    flux = getflux(source,frequencies)
    dir  = measure(frame,source.dir,"AZEL")
    RFISource(source.name,dir,flux,frequencies)
end

################################################################################
# Flux

function getflux(source::PowerLawSource,frequency::quantity(Float64,Hertz))
    logflux = log10(source.flux)
    logfreq = log10(frequency/source.reffreq)
    for (i,index) in enumerate(source.index)
        logflux += index*logfreq.^i
    end
    10.0.^logflux
end

function getflux(source::AbstractSource,frequencies::Vector{quantity(Float64,Hertz)})
    [getflux(source,frequency) for frequency in frequencies]
end

################################################################################
# Position

function getazel(frame::ReferenceFrame,dir::Direction)
    if dir.system != "AZEL"
        dir = measure(frame,dir,"AZEL")
    end
    az = dir.m[1]
    el = dir.m[2]
    az,el
end
getazel(frame::ReferenceFrame,ra,dec) = getazel(frame,Direction("J2000",ra,dec))
getazel(frame::ReferenceFrame,source::Source) = getazel(frame,source.dir)

@doc """
Convert a given RA and dec to the standard radio coordinate system.
""" ->
function getlm(frame::ReferenceFrame,dir::Direction)
    az,el = getazel(frame,dir)
    l = cos(el)*sin(az)
    m = cos(el)*cos(az)
    l,m
end
getlm(frame::ReferenceFrame,ra,dec) = getlm(frame,Direction("J2000",ra,dec))
getlm(frame::ReferenceFrame,source::Source) = getlm(frame,source.dir)

@doc """
Returns true if the source is above the horizon, false if the source
is below the horizon.
""" ->
function isabovehorizon(frame::ReferenceFrame,source::Source)
    az,el = getazel(frame,source)
    ifelse(el > 0.0Radian,true,false)
end

@doc """
Filter the provided list of sources down to those that are above
the horizon in the given reference frame.
""" ->
function abovehorizon(frame::ReferenceFrame,sources::Vector{Source})
    sources_abovehorizon = Source[]
    for source in sources
        if isabovehorizon(frame,source)
            push!(sources_abovehorizon,source)
        end
    end
    sources_abovehorizon
end

################################################################################
# I/O

function readsources(filename::AbstractString)
    sources = TTCal.Source[]
    parsed_sources = JSON.parsefile(filename)
    for parsed_source in parsed_sources
        name  = parsed_source["name"]
        ra    = parsed_source["ra"]
        dec   = parsed_source["dec"]
        flux  = parsed_source["flux"]
        freq  = parsed_source["freq"]
        index = parsed_source["index"]
        dir = Direction("J2000",ra_str(ra),dec_str(dec))
        push!(sources,TTCal.Source(name,dir,flux,freq*Hertz,index))
    end
    sources
end

function writesources(filename::AbstractString,sources::Vector{Source})
    dicts = Dict{UTF8String,Any}[]
    for source in sources
        dict = Dict{UTF8String,Any}()
        dict["ref"]   = "TTCal"
        dict["name"]  = source.name
        dict["ra"]    =  ra_str(source.dir.m[1])
        dict["dec"]   = dec_str(source.dir.m[2])
        dict["flux"]  = source.flux
        dict["freq"]  = float(source.reffreq)
        dict["index"] = source.index
        push!(dicts,dict)
    end
    file = open(filename,"w")
    JSON.print(file,dicts)
    close(file)
    nothing
end

