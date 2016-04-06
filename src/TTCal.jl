# Copyright (c) 2015 Michael Eastwood
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

__precompile__()

module TTCal

export JonesMatrix, DiagonalJonesMatrix, HermitianJonesMatrix
export StokesVector, MuellerMatrix

export Visibilities, Metadata, Nant, Nfreq, Nbase
export collect_metadata, flag_short_baselines!
export get_data, set_corrected_data!

export PointSource, GaussianSource, MultiSource, PowerLaw
export readsources, writesources
export ConstantBeam, SineBeam, Memo178Beam

export genvis, subsrc!, getspec, fitvis

export GainCalibration, gaincal
export PolarizationCalibration, polcal
export applycal!, corrupt!, peel!

importall Base.Operators
import Base: zero, one, rand, conj, det, inv, norm, kron

using ArgParse
using JSON
using FileIO, JLD
using NPZ
using ProgressMeter
using CasaCore.Measures
using CasaCore.Tables

const c = 2.99792e+8

include("rungekutta.jl")
include("stokes.jl")
include("sourcemodel.jl")
include("beammodel.jl")
include("utm.jl")
include("ionosphere.jl")
include("measurementsets.jl")
include("genvis.jl")
include("getspec.jl")
include("subsrc.jl")
include("fitvis.jl")
include("calibration.jl")
include("peel.jl")
include("commandline.jl")

end

