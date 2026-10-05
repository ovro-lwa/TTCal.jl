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

"Define some helper functions for transforming between arrays and TTCal Datasets."

#export array_to_ttcal, array_to_ttcal!
#export ttcal_to_array
#export pack_jones_matrix, unpack_jones_matrix!

#using TTCal

function array_to_ttcal(input, metadata, time, T)
    # Pack all frequency channels of the input array into a TTCal Dataset
    array_to_ttcal(input, metadata, 1:Nfreq(metadata), time, T)
end

function array_to_ttcal(input, metadata, frequencies, time, T)
    # Pack selected frequency channels of the input array into a TTCal Dataset
    metadata = deepcopy(metadata)
    slice!(metadata, frequencies, axis=:frequency)
    slice!(metadata, time,        axis=:time)
    output = Dataset(metadata, polarization=T)
    array_to_ttcal!(output, input, frequencies, 1, T)
    output
end

function array_to_ttcal!(output, input, frequencies, time, T)
    # Pack selected frequency channels of the input array into a TTCal Dataset
    for (frequency, frequency′) in enumerate(frequencies)
        # `frequency`  refers to the channel index within the output TTCal Dataset
        # `frequency′` refers to the channel index within the input array
        visibilities = output[frequency, time]
        α = 1
        for antenna1 = 1:Nant(output), antenna2 = antenna1:Nant(output)
            J = pack_jones_matrix(input, frequency′, α, T)
            if J.xx != 0 && J.yy != 0
                visibilities[antenna1, antenna2] = J
            end
            α += 1
        end
    end
end

function pack_jones_matrix(array, frequency, α, ::Type{Full})
    JonesMatrix(array[1, frequency, α], array[2, frequency, α],
                array[3, frequency, α], array[4, frequency, α])
end
function pack_jones_matrix(array, frequency, α, ::Type{Dual})
    if size(array)[1] == 2
        DiagonalJonesMatrix(array[1, frequency, α], array[2, frequency, α])
    else
        DiagonalJonesMatrix(array[1, frequency, α], array[4, frequency, α])
    end
end
function pack_jones_matrix(array, frequency, α, ::Type{XX})
    array[1, frequency, α]
end
function pack_jones_matrix(array, frequency, α, ::Type{YY})
    array[2, frequency, α]
end

function ttcal_to_array(ttcal_dataset)
    npol = polarization(ttcal_dataset) == Dual ? 2 : 4
    data = zeros(ComplexF64, npol, Nfreq(ttcal_dataset), Nbase(ttcal_dataset), Ntime(ttcal_dataset))
    for ti in 1:Ntime(ttcal_dataset)
        _data = zeros(ComplexF64, npol, Nfreq(ttcal_dataset), Nbase(ttcal_dataset))
        for frequency in 1:Nfreq(ttcal_dataset)
            visibilities = ttcal_dataset[frequency, ti]
            α = 1
            for antenna1 = 1:Nant(ttcal_dataset), antenna2 = antenna1:Nant(ttcal_dataset)
                J = visibilities[antenna1, antenna2]
                unpack_jones_matrix!(_data, frequency, α, J, polarization(ttcal_dataset))
                α += 1
            end
        end
        data[:, :, :, ti] = _data[:, :, :]
    end
    if Ntime(ttcal_dataset) == 1
        data = data[:, :, :, 1]
    end
    data
end

function unpack_jones_matrix!(data, frequency, α, J, ::Type{Full})
    data[1, frequency, α] = J.xx
    data[2, frequency, α] = J.xy
    data[3, frequency, α] = J.yx
    data[4, frequency, α] = J.yy
end
function unpack_jones_matrix!(data, frequency, α, J, ::Type{Dual})
    data[1, frequency, α] = J.xx
    data[2, frequency, α] = J.yy
end
function unpack_jones_matrix!(data, frequency, α, J, ::Type{XX})
    data[1, frequency, α] = J
end
function unpack_jones_matrix!(data, frequency, α, J, ::Type{YY})
    data[2, frequency, α] = J
end


