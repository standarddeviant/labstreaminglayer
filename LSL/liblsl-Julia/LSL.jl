# Everything below is an attempt to make a Julia interface, via the C 
# interface and ccall in julia. Originally, only the minimal effort and
# changes will be implemented.

# Dave Crist 2017
# module LSL

# START JULIA BOILERPLATE CONFIG
# FIXME put using XXX here
# FIXME put using XXX here
# FIXME put using XXX here

# using BigLib: thing1, thing2

# import Base.show

# importall OtherLib
# END JULIA BOILERPLATE CONFIG

# const LSLBIN = ""
# function set_lslbin(inp)
#     LSLBIN = inp
# end
# DRCFIX Is there a cleaner way to make a setter for a variable that requires const?
#        this seems counter-intuitive... do we need const for LSLBIN???

const LSLBIN = "liblsl64" # FIXME - support 32-bit???

# Julia convenience functions
function ptr2str(inp,funcname=nothing)
    tmpptr = Ptr{Cchar}(inp)
    if tmpptr == C_NULL
        error("Unable to convert ptr to str (ptr==C_NULL)" *
            "$(funcname!=nothing?" from "*funcname:"")")
    end
    unsafe_string(tmpptr)
end

"""Julia API for the lab streaming layer.

This Julia API is closely modeled after the Python API.

The lab streaming layer provides a set of functions to make instrument data
accessible in real time within a lab network. From there, streams can be
picked up by recording programs, viewing programs or custom experiment
applications that access data streams in real time.

The API covers two areas:
- The "push API" allows to create stream outlets and to push data (regular
  or irregular measurement time series, event data, coded audio/video frames,
  etc.) into them.
- The "pull API" allows to create stream inlets and read time-synched
  experiment data from them (for recording, viewing or experiment control).

LSL.jl has been tested with Julia 0.6

"""

# import os
# import platform
# import struct
# from ctypes import CDLL, util, byref, c_char_p, c_void_p, c_double, c_int, \
#     c_long, c_float, c_short, c_byte, c_longlong, cast, POINTER

# __all__ = ["IRREGULAR_RATE", "DEDUCED_TIMESTAMP", "FOREVER", "cf_float32",
#            "cf_double64", "cf_string", "cf_int32", "cf_int16", "cf_int8",
#            "cf_int64", "cf_undefined", "protocol_version", "library_version",
#            "local_clock", "StreamInfo", "StreamOutlet", "resolve_streams",
#            "resolve_byprop", "resolve_bypred", "StreamInlet", "XMLElement",
#            "ContinuousResolver", "TimeoutError", "LostError",
#            "InvalidArgumentError", "InternalError", "stream_info",
#            "stream_outlet", "stream_inlet", "xml_element", "timeout_error",
#            "lost_error", "vectorf", "vectord", "vectorl", "vectori",
#            "vectors", "vectorc", "vectorstr", "resolve_stream"]

# DRCFIX - add export back in for actual module
# export IRREGULAR_RATE, DEDUCED_TIMESTAMP, FOREVER, cf_float32,     \
#        cf_double64, cf_string, cf_int32, cf_int16, cf_int8,       \
#        cf_int64, cf_undefined, protocol_version, library_version, \
#        local_clock, StreamInfo, StreamOutlet, resolve_streams,    \
#        resolve_byprop, resolve_bypred, StreamInlet, XMLElement,   \
#        ContinuousResolver, TimeoutError, LostError,               \
#        InvalidArgumentError, InternalError, stream_info,          \
#        stream_outlet, stream_inlet, xml_element, timeout_error,   \
#        lost_error, vectorf, vectord, vectorl, vectori,            \
#        vectors, vectorc, vectorstr, resolve_stream



        #    struct MyType
        #        x
        #    end
           
        #    bar(x) = 2x
        #    foo(a::MyType) = bar(a.x) + 1
           
        #    show(io::IO, a::MyType) = print(io, "MyType $(a.x)")
        #    end
           
# =================
# === Constants ===
# =================

# Constant to indicate that a stream has variable sampling rate.
const IRREGULAR_RATE = 0.0

# Constant to indicate that a sample has the next successive time stamp
# according to the stream"s defined sampling rate. Optional optimization to
# transmit less data per sample.
const DEDUCED_TIMESTAMP = -1.0

# A very large time value (ca. 1 year); can be used in timeouts.
const FOREVER = 32000000.0

# Value formats supported by LSL. LSL data streams are sequences of samples,
# each of which is a same-size vector of values with one of the below types.

# For up to 24-bit precision measurements in the appropriate physical unit (
# e.g., microvolts). Integers from -16777216 to 16777216 are represented
# accurately.
const cf_float32 = 1
# For universal numeric data as long as permitted by network and disk budget.
#  The largest representable integer is 53-bit.
const cf_double64 = 2
# For variable-length ASCII strings or data blobs, such as video frames,
# complex event descriptions, etc.
const cf_string = 3
# For high-rate digitized formats that require 32-bit precision. Depends
# critically on meta-data to represent meaningful units. Useful for
# application event codes or other coded data.
const cf_int32 = 4
# For very high bandwidth signals or CD quality audio (for professional audio
#  float is recommended).
const cf_int16 = 5
# For binary signals or other coded data.
const cf_int8 = 6
# For now only for future compatibility. Support for this type is not
# available on all languages and platforms.
const cf_int64 = 7
# Can not be transmitted.
const cf_undefined = 0

# Post processing flags
const proc_none = 0
const proc_clocksync = 1
const proc_dejitter = 2
const proc_monotonize = 4
const proc_threadsafe = 8
const proc_ALL = proc_none | proc_clocksync | proc_dejitter | proc_monotonize | proc_threadsafe





# DRCNOTE, the below types like fmt2type used to be at bottom of file, 
# DRCNOTE, but for Julia, they logically make more sense at the top of the file
# set up some type maps
string2fmt = Dict("float32" => cf_float32, "double64" => cf_double64,
                  "string"  => cf_string,  "int32"    => cf_int32, 
                  "int16"   => cf_int16,   "int8"     => cf_int8, 
                  "int64"   => cf_int64)
fmt2string = ["undefined", "float32", "double64", "string", "int32", "int16",
    "int8", "int64"]
fmt2type = [[], Cfloat, Cdouble, Cstring, Cint, Cshort, Cchar, Clonglong]
LSL_VALUE_TYPE_UNION = Union{fmt2type[2:end]...}
# fmt2push_sample = [[], lib.lsl_push_sample_ftp, lib.lsl_push_sample_dtp,
#                    lib.lsl_push_sample_strtp, lib.lsl_push_sample_itp,
#                    lib.lsl_push_sample_stp, lib.lsl_push_sample_ctp, []]
# fmt2pull_sample = [[], lib.lsl_pull_sample_f, lib.lsl_pull_sample_d,
#                    lib.lsl_pull_sample_str, lib.lsl_pull_sample_i,
#                    lib.lsl_pull_sample_s, lib.lsl_pull_sample_c, []]
# DRCNOTE , switching from Python functions to Julia Symbols for use with ccall
fmt2push_sample = [[], :lsl_push_sample_ftp, :lsl_push_sample_dtp,
    :lsl_push_sample_strtp, :lsl_push_sample_itp,
    :lsl_push_sample_stp, :lsl_push_sample_ctp, []]
# LSL_PUSH_SAMP_TYPE_UNION = fmt2push_sample[2:end-1]

fmt2pull_sample = [[], :lsl_pull_sample_f, :lsl_pull_sample_d,
    :lsl_pull_sample_str, :lsl_pull_sample_i,
    :lsl_pull_sample_s, :lsl_pull_sample_c, []]
# LSL_PULL_SAMP_TYPE_UNION = fmt2pull_sample[2:end-1]

# try
fmt2push_chunk = [[], :lsl_push_chunk_ftp, :lsl_push_chunk_dtp,
    :lsl_push_chunk_strtp, :lsl_push_chunk_itp,
    :lsl_push_chunk_stp, :lsl_push_chunk_ctp, []]
# LSL_PUSH_CHUNK_TYPE_UNION = fmt2push_chunk[2:end-1]

fmt2pull_chunk = [[], :lsl_pull_chunk_f, :lsl_pull_chunk_d,
    :lsl_pull_chunk_str, :lsl_pull_chunk_i,
    :lsl_pull_chunk_s, :lsl_pull_chunk_c, []]
# LSL_PULL_CHUNK_TYPE_UNION = fmt2pull_chunk[2:end-1]

# catch
#     # if not available
#     fmt2push_chunk = [nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing]
#     fmt2pull_chunk = [nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing]
# end

# cf_xxx integers have to be zero-based for C-interface, but these 


# ==========================================================
# === Free Functions provided by the lab streaming layer ===
# ==========================================================

"""Protocol version.

The major version is protocol_version() / 100;
The minor version is protocol_version() % 100;

Clients with different minor versions are protocol-compatible with each 
other while clients with different major versions will refuse to work 
together.

"""
function protocol_version()
    ccall((:lsl_protocol_version, LSLBIN), Cint, ())
end



"""Version of the underlying liblsl library.

The major version is library_version() / 100;
The minor version is library_version() % 100;

"""
function library_version()
    ccall((:lsl_library_version, LSLBIN), Cint, ())
end


"""Obtain a local system time stamp in seconds.

The resolution is better than a milisecond. This reading can be used to 
assign time stamps to samples as they are being acquired.

If the "age" of a sample is known at a particular time (e.g., from USB 
transmission delays), it can be used as an offset to lsl_local_clock() to 
obtain a better estimate of when a sample was actually captured. See 
StreamOutlet.push_sample() for a use case.

"""
function local_clock()    
    ccall((:lsl_library_version, LSLBIN), Cint, ())
end


# ==========================
# === Stream Declaration ===
# ==========================
    
"""The StreamInfo object stores the declaration of a data stream.

Represents the following information:

1) stream data format (#channels, channel format)
2) core information (stream name, content type, sampling rate)
3) optional meta-data about the stream content (channel labels, 
measurement units, etc.)

Whenever a program wants to provide a new stream on the lab network it will 
typically first create a StreamInfo to describe its properties and then 
construct a StreamOutlet with it to create the stream on the network. 
Recipients who discover the outlet can query the StreamInfo; it is also 
written to disk when recording the stream (playing a similar role as a file 
header).

"""
mutable struct StreamInfo
    obj::Ptr{Void} # should this be more specific???
end

"""Construct a new StreamInfo object.

Core stream information is specified here. Any remaining meta-data can 
be added later.

Keyword arguments:
* name -- Name of the stream. Describes the device (or product series)    
        that this stream makes available (for use by programs, 
        experimenters or data analysts). Cannot be empty.
* type -- Content type of the stream. By convention LSL uses the content 
        types defined in the XDF file format specification where 
        applicable (https://github.com/sccn/xdf). The content type is the 
        preferred way to find streams (as opposed to searching by name).
* channel_count -- Number of channels per sample. This stays constant for 
                    the lifetime of the stream. (default 1)
* nominal_srate -- The sampling rate (in Hz) as advertised by the data 
                    source, regular (otherwise set to IRREGULAR_RATE).
                    (default IRREGULAR_RATE)
* channel_format -- Format/type of each channel. If your channels have 
                    different formats, consider supplying multiple 
                    streams or use the largest type that can hold 
                    them all (such as cf_double64). It is also allowed 
                    to pass this as a string, without the cf_ prefix,
                    e.g., "float32" (default cf_float32)
* source_id -- Unique identifier of the device or source of the data, if 
                available (such as the serial number). This is critical 
                for system robustness since it allows recipients to 
                recover from failure even after the serving app, device or 
                computer crashes (just by finding a stream with the same 
                source id on the network again). Therefore, it is highly 
                recommended to always try to provide whatever information 
                can uniquely identify the data source itself.
                (default "")

"""
function StreamInfo(name="untitled", type_="", channel_count=1,
                nominal_srate=IRREGULAR_RATE, channel_format=cf_float32,
                source_id=""; handle=nothing)
    
    # @show name
    # @show type_
    # @show Cint(channel_count)
    # @show Cdouble(nominal_srate)
    # @show Cint(channel_format)
    # @show source_id
    # @show handle

    # DRCFIX DOES str2fmt NEED TO BE ABOVE???
    if isa(channel_format, AbstractString)
        channel_format = string2fmt[channel_format]
    end
    # self.obj = lib.lsl_create_streaminfo(c_char_p(str.encode(name)),
    #                                         c_char_p(str.encode(type)),
    #                                         channel_count,
    #                                         c_double(nominal_srate),
    #                                         channel_format,
    #                                         c_char_p(str.encode(source_id)))
    # extern LIBLSL_C_API lsl_streaminfo lsl_create_streaminfo(
            # char *name, 
            # char *type, 
            # int channel_count, 
            # double nominal_srate, 
            # lsl_channel_format_t channel_format, 
            # char *source_id);
    obj = ccall((:lsl_create_streaminfo, LSLBIN), 
        Ptr{Void}, 
        (Cstring, Cstring, Cshort, Cdouble, Cint, Cstring), 
        pointer(name), pointer(type_), Cshort(channel_count), Cdouble(nominal_srate), 
            Cint(channel_format), pointer(source_id)
    )
    # pointer(name), pointer(type_), Cshort(channel_count), Cdouble(nominal_srate), 
    obj = Ptr{Void}(obj)
    if obj == C_NULL
        error("could not create stream description object.") #raise RuntimeError
    end
    StreamInfo(obj)
end # function StreamInfo

# function StreamInfo(;handle=nothing)
#     obj = Ptr{Void}()
#     if obj == C_NULL
#         error("could not create stream description object.") #raise RuntimeError
#     end
#     StreamInfo(obj)
# end

# DRCFIX - convert to finalizer to free memory, read up on Julia best practice for other C-wrappers
# DRCFIX - look @ https://discourse.julialang.org/t/properly-using-finalizer-ccall-cconvert-and-unsafe-convert/6183/6
""" Destroy a previously created StreamInfo object. """
function del(self::StreamInfo)
    try
        # lib.lsl_destroy_streaminfo(x.obj)
        ccall((:lsl_destroy_streaminfo, LSLBIN), Void, (Ptr{Void},), self.obj)
    end
end

# === Core Information (assigned at construction) ===

"""Name of the stream.

This is a human-readable name. For streams offered by device modules, 
it refers to the type of device or product series that is generating 
the data of the stream. If the source is an application, the name may 
be a more generic or specific identifier. Multiple streams with the 
same name can coexist, though potentially at the cost of ambiguity (for 
the recording app or experimenter).

"""
function name(self::StreamInfo)
    #lib.lsl_get_name(self.obj).decode("utf-8")
    outp = ccall((:lsl_get_name, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    # convert Cstring to Julia string if outp is not NULL
    ptr2str(outp)
end

"""Content type of the stream.

The content type is a short string such as "EEG", "Gaze" which 
describes the content carried by the channel (if known). If a stream 
contains mixed content this value need not be assigned but may instead 
be stored in the description of channel types. To be useful to 
applications and automated processing systems using the recommended 
content types is preferred.

"""
function type_(self::StreamInfo)
    # return lib.lsl_get_type(self.obj).decode("utf-8")
    outp = ccall((:lsl_get_type, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    # convert Cstring to Julia string if outp is not NULL
    ptr2str(outp)
end
    
"""Number of channels of the stream.

A stream has at least one channel; the channel count stays constant for
all samples.

"""
function channel_count(self::StreamInfo)
    # return lib.lsl_get_channel_count(self.obj)
    ccall((:lsl_get_channel_count, LSLBIN), Cint, (Ptr{Void},), self.obj)
end
    
"""Sampling rate of the stream, according to the source (in Hz).

If a stream is irregularly sampled, this should be set to
IRREGULAR_RATE.

Note that no data will be lost even if this sampling rate is incorrect 
or if a device has temporary hiccups, since all samples will be 
transmitted anyway (except for those dropped by the device itself). 
However, when the recording is imported into an application, a good 
data importer may correct such errors more accurately if the advertised 
sampling rate was close to the specs of the device.

"""
function nominal_srate(self::StreamInfo)
    # return lib.lsl_get_nominal_srate(self.obj)
    ccall((:lsl_get_nominal_srate, LSLBIN), Cint, (Ptr{Void},), self.obj)
end

"""Channel format of the stream.

All channels in a stream have the same format. However, a device might 
offer multiple time-synched streams each with its own format.

"""
function channel_format(self::StreamInfo)
    # return lib.lsl_get_channel_format(self.obj)
    ccall((:lsl_get_channel_format, LSLBIN), Cint, (Ptr{Void},), self.obj)
end

"""Unique identifier of the stream"s source, if available.

The unique source (or device) identifier is an optional piece of 
information that, if available, allows that endpoints (such as the 
recording program) can re-acquire a stream automatically once it is 
back online.

"""
function source_id(self::StreamInfo)
    # return lib.lsl_get_source_id(self.obj).decode("utf-8")
    outp = ccall((:lsl_get_source_id, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    # convert Cstring to Julia string if outp is not NULL
    ptr2str(outp)
end
    
# === Hosting Information (assigned when bound to an outlet/inlet) ===
    
"""Protocol version used to deliver the stream."""
function version(self::StreamInfo)
    # return lib.lsl_get_version(self.obj)
    ccall((:lsl_get_version, LSLBIN), Cint, (Ptr{Void},), self.obj)
end


"""Creation time stamp of the stream.

This is the time stamp when the stream was first created
(as determined via local_clock() on the providing machine).

"""
function created_at(self::StreamInfo)
    # return lib.lsl_get_created_at(self.obj)
    ccall((:lsl_get_created_at, LSLBIN), Cdouble, (Ptr{Void},), self.obj)
end

"""Unique ID of the stream outlet instance (once assigned).

This is a unique identifier of the stream outlet, and is guaranteed to 
be different across multiple instantiations of the same outlet (e.g., 
after a re-start).

"""
function uid(self::StreamInfo)
    # return lib.lsl_get_uid(self.obj).decode("utf-8")
    # DRCFIX - is more needed to safely retrieve Cstring here???
    outp = ccall((:lsl_get_uid, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    if outp == C_NULL
        error("Unable to resolve uid, received C_NULL from lsl_get_uid")
    end
    ptr2str(outp) # convert Ptr{Cchar} to a Julia String
end

"""Session ID for the given stream.

The session id is an optional human-assigned identifier of the 
recording session. While it is rarely used, it can be used to prevent 
concurrent recording activitites on the same sub-network (e.g., in 
multiple experiment areas) from seeing each other"s streams 
(can be assigned in a configuration file read by liblsl, see also 
Network Connectivity in the LSL wiki).

"""
function session_id(self::StreamInfo)
    # return lib.lsl_get_session_id(self.obj).decode("utf-8")
    # DRCFIX - is more needed to safely retrieve Cstring here???
    outp = ccall((:lsl_get_session_id, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    if outp == C_NULL
        error("Unable to resolve uid, received C_NULL from lsl_get_session_id")
    end
    ptr2str(outp) # convert Ptr{Cchar} to a Julia String    
end
    
"""Hostname of the providing machine."""
function hostname(self::StreamInfo)
    # return lib.lsl_get_hostname(self.obj).decode("utf-8")
    # DRCFIX - is more needed to safely retrieve Cstring here???
    outp = ccall((:lsl_get_hostname, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    if outp == C_NULL
        error("Unable to resolve uid, received C_NULL from lsl_get_hostname")
    end
    ptr2str(outp) # convert Ptr{Cchar} to a Julia String    
end
    
# === Data Description (can be modified) ===

"""Extended description of the stream.

It is highly recommended that at least the channel labels are described 
here. See code examples on the LSL wiki. Other information, such 
as amplifier settings, measurement units if deviating from defaults, 
setup information, subject information, etc., can be specified here, as 
well. Meta-data recommendations follow the XDF file format project
(github.com/sccn/xdf/wiki/Meta-Data or web search for: XDF meta-data).

Important: if you use a stream content type for which meta-data 
recommendations exist, please try to lay out your meta-data in 
agreement with these recommendations for compatibility with other 
applications.

"""
function desc(self::StreamInfo)
    XMLElement(ccall((:lsl_get_desc, LSLBIN),
        Ptr{Void},
        (Ptr{Void},),
        self.obj
    ))
end
   
"""Retrieve the entire stream_info in XML format.

This yields an XML document (in string form) whose top-level element is 
<description>. The description element contains one element for each
field of the stream_info class, including:
a) the core elements <name>, <type>, <channel_count>, <nominal_srate>, 
    <channel_format>, <source_id>
b) the misc elements <version>, <created_at>, <uid>, <session_id>, 
    <v4address>, <v4data_port>, <v4service_port>, <v6address>, 
    <v6data_port>, <v6service_port>
c) the extended description element <desc> with user-defined 
    sub-elements.

"""
function as_xml(self::StreamInfo)
    # return lib.lsl_get_xml(self.obj).decode("utf-8")
    outp = ccall((:lsl_get_xml, LSLBIN), Cstring, (Ptr{Void},), self.obj)
    # convert Cstring to Julia string if outp is not NULL
    ptr2str(outp)
end
        

# =====================    
# === Stream Outlet ===
# =====================
        

"""A stream outlet.

Outlets are used to make streaming data (and the meta-data) available on 
the lab network.

"""
# mutable struct StreamOutlet{T<:LSL_VALUE_TYPE_UNION, PS::Symbol, PC::Symbol}
mutable struct StreamOutlet{T, PS, PC}
    obj::Ptr{Void}
    # DRCFIX what are the types of these vars?
    channel_format_ # = info.channel_format()                  # Cint
    channel_count_  # = info.channel_count()                   # Cint
    # do_push_sample # = fmt2push_sample[self.channel_format]   # Julia func (currently)
    # do_push_chunk  # = fmt2push_chunk[self.channel_format]    # Julia func (currently)
    # value_type     # = fmt2type[self.channel_format]          # [ Cfloat | Cint | etc. ]
    # sample_type    # = self.value_type*self.channel_count     # 
end
    
"""Establish a new stream outlet. This makes the stream discoverable.

Keyword arguments:
* description -- The StreamInfo object to describe this stream. Stays
        constant over the lifetime of the outlet.
* chunk_size --- Optionally the desired chunk granularity (in samples) 
                for transmission. If unspecified, each push operation 
                yields one chunk. Inlets can override this setting.
                (default 0)
* max_buffered -- Optionally the maximum amount of data to buffer (in 
                seconds if there is a nominal sampling rate, otherwise 
                x100 in samples). The default is 6 minutes of data. 
                Note that, for high-bandwidth data, you will want to 
                use a lower value here to avoid running out of RAM.
                (default 360)

"""
function StreamOutlet(info_::StreamInfo, chunk_size=0, max_buffered=360)
    obj = Ptr{Void}(ccall((:lsl_create_outlet, LSLBIN), 
            Ptr{Void},
            (Ptr{Void}, Cint, Cint),
            info_.obj, Cint(chunk_size), Cint(max_buffered)
    ))
    if obj == C_NULL
        error("could not create stream outlet, obj==C_NULL")
    end
    channel_format_ = channel_format(info_)
    channel_count_  = channel_count(info_)
    do_push_sample  = fmt2push_sample[channel_format_+1]
    do_push_chunk   = fmt2push_chunk[channel_format_+1]
    # value_type     = fmt2type[self.channel_format]
    # sample_type    = fmt2type[self.channel_format] * channel_count # DRCFIX, can't use ctypes trick...
    StreamOutlet{fmt2type[channel_format_+1], do_push_sample, do_push_chunk}(
        obj,
        channel_format_,
        channel_count_,
        # do_push_sample_,
        # do_push_chunk_,
        # value_type,
        # sample_type
    )
end
                
"""Destroy an outlet.

The outlet will no longer be discoverable after destruction and all 
connected inlets will stop delivering data.

"""
function del(self::StreamOutlet)
    # noinspection PyBroadException
    try
        # lib.lsl_destroy_outlet(self.obj)
        # const tmpptr = Ptr{Void}(self.obj)
        ccall((:lsl_destroy_outlet, LSLBIN), Void, (Ptr{Void},), self.obj)
    end
end

"""Push a sample into the outlet.

Each entry in the list corresponds to one channel.

Keyword arguments:
* x -- A list of values to push (one per channel).
* timestamp -- Optionally the capture time of the sample, in agreement 
                with local_clock(); if omitted, the current 
                time is used. (default 0.0)
* pushthrough -- Whether to push the sample through to the receivers  
                instead of buffering it with subsequent samples. 
                Note that the chunk_size, if specified at outlet 
                construction, takes precedence over the pushthrough flag.
                (default True)

"""
function push_sample(self::StreamOutlet{T,PS,PC}, x::AbstractArray,
        timestamp=0.0, pushthrough=true) where {T<:LSL_VALUE_TYPE_UNION, PS, PC}
    if length(x) == self.channel_count_
        # DRCFIX - is this needed for julia????
        # if self.channel_format == cf_string 
        #     x = [v.encode("utf-8") for v in x]
        # end
        tmpx = Vector{T}(x)
        # tmpts = Cdouble(timestamp)
        # tmppt = Cint(pushthrough)
        # self.obj, tmpx, tmpts, tmppt
        value_type = T #self.value_type
        handle_error(ccall((PS, LSLBIN),
            Cint, # output type # DRCFIX double check this
            (Ptr{Void}, Ptr{T}, Cdouble, Cint), # input types
            Ptr{Void}(self.obj), tmpx, Cdouble(timestamp), Cint(pushthrough)
        ))
    else
        error("length of the data must correspond to the stream's channel count." * 
              "length(x) = $(length(x)), self.channel_count_ = $(self.channel_count_)")
    end
end

"""Push a list of samples into the outlet.

* samples -- A list of samples, either as a list of lists or a list of  
            multiplexed values.
* timestamp -- Optionally the capture time of the most recent sample, in 
                agreement with local_clock(); if omitted, the current 
                time is used. The time stamps of other samples are 
                automatically derived according to the sampling rate of 
                the stream. (default 0.0)
* pushthrough Whether to push the chunk through to the receivers instead 
            of buffering it with subsequent samples. Note that the 
            chunk_size, if specified at outlet construction, takes 
            precedence over the pushthrough flag. (default True)

"""
function push_chunk(self::StreamOutlet{T,PS,PC}, x::AbstractArray, 
        timestamp=0.0, pushthrough=true) where {T<:LSL_VALUE_TYPE_UNION, PS<:Symbol, PC<:Symbol}
    try
        if typeof(x[1]) <: AbstractArray
            # DRCNOTE - is there a good enough reason to accept "list of lists" and not just N-dimensional arrays?
            # In Julia, N-Dimensional Arrays are "first-class" objects 
            # In this context, "first-class" object means the object has existed since the inception of
            # language and exists in every commonly used version of the language
            # Whereas in Python, you only get N-dimensional arrays from NumPy, and these are not "first-class" objects
            # in Python, despite the widespread use of NumPy
            throw(ErrorException(
                "The API for push_chunk is expecting an N-dimensional Julia Array, not an 'Array of Arrays'"))
        end

        # n_values = self.channel_count * length(x)
        # data_buff = (self.value_type * n_values).from_buffer(x) # DRCFIX
        n_values = length(x) # this works well is x is an AbstractArray and 
        data_buff = Vector{T}(vec(x))
        handle_error(ccall((PC, LSLBIN),
            Cint, # inferred via https://github.com/sccn/labstreaminglayer/blob/8d032fb43245be0d8598488d2cf783ac36a97831/LSL/liblsl/include/lsl_c.h#L498
            (Ptr{Void}, Ptr{T}, Clong, Cdouble, Cint),
            self.obj, data_buff, Clong(n_values), Cdouble(timestamp), Cint(pushthrough)
        ))
    catch TypeError TE
        println("I don't think should this happen at all... vec(x) shold obviate this block...")
        println("Even for value_type of String, vec(x) shold obviate this block...")
        println("If this is seen in operation, it is an unhandled exception, and the code should be fixed.")
        # if length(x)
        #     if isa(x[0], AbstractArray)
        #         x = [v for sample in x for v in sample]
        #     end
        #     # DRCFIX is this necessary in Julia???
        #     # if self.channel_format == cf_string:
        #     #     x = [v.encode("utf-8") for v in x]
        #     # end
        #     if length(x) % self.channel_count == 0:
        #         constructor = self.value_type*len(x)
        #         # noinspection PyCallingNonCallable
        #         handle_error(
        #             self.do_push_chunk(self.obj, constructor(*x),
        #                                         c_long(len(x)),
        #                                         c_double(timestamp),
        #                                         c_int(pushthrough)))
        #     else
        #         raise ValueError("each sample must have the same number of "
        #                             "channels.")
        #     end
        # end
    end # try / catch
end # push_chunk
                            
"""Check whether consumers are currently registered.

While it does not hurt, there is technically no reason to push samples 
if there is no consumer.

"""
function have_consumers(self::StreamOutlet)
    # return bool(lib.lsl_have_consumers(self.obj))
    # return type (Cint) inferred via https://github.com/sccn/labstreaminglayer/blob/master/LSL/liblsl/include/lsl_c.h#L586
    ccall((:lsl_have_consumers, LSLBIN), Cint, (Ptr{Void},), self.obj)
end
    
"""Wait until some consumer shows up (without wasting resources).

Returns True if the wait was successful, False if the timeout expired.

"""
function wait_for_consumers(self::StreamOutlet, timeout)
    # return bool(lib.lsl_wait_for_consumers(self.obj, c_double(timeout)))
    ccall((:lsl_wait_for_consumers, LSLBIN), 
        Cint, 
        (Ptr{Void}, Cdouble),
        self.obj, Cdouble(timeout)
    )
end

 
# =========================
# === Resolve Functions ===
# =========================

"""Resolve all streams on the network.

This function returns all currently available streams from any outlet on 
the network. The network is usually the subnet specified at the local 
router, but may also include a group of machines visible to each other via 
multicast packets (given that the network supports it), or list of 
hostnames. These details may optionally be customized by the experimenter 
in a configuration file (see Network Connectivity in the LSL wiki).  

Keyword arguments:
* wait_time -- The waiting time for the operation, in seconds, to search for 
                streams. Warning: If this is too short (<0.5s) only a subset 
                (or none) of the outlets that are present on the network may 
                be returned. (default 1.0)
                
Returns a list of StreamInfo objects (with empty desc field), any of which 
can subsequently be used to open an inlet. The full description can be
retrieved from the inlet.

"""
function resolve_streams(wait_time=1.0)
    # noinspection PyCallingNonCallable
    buffer = Vector{Ptr{Void}}(1024) #c_void_p*1024)()
    # num_found = lib.lsl_resolve_all(byref(buffer), 1024, c_double(wait_time))
    num_found = ccall((:lsl_resolve_all, LSLBIN), 
        Cint, 
        (Ptr{Ptr{Void}}, Cint, Cdouble),
        pointer(buffer), Cint(1024), Cdouble(wait_time)
    )
    println("num_found = $(num_found)")
    return [StreamInfo(handle=buffer[k]) for k in range(1,num_found)]
end


"""Resolve all streams with a specific value for a given property.

If the goal is to resolve a specific stream, this method is preferred over 
resolving all streams and then selecting the desired one.

Keyword arguments:
* prop -- The StreamInfo property that should have a specific value (e.g.,   
        "name", "type", "source_id", or "desc/manufaturer").
* value -- The string value that the property should have (e.g., "EEG" as 
            the type property).
* minimum -- Return at least this many streams. (default 1)
* timeout -- Optionally a timeout of the operation, in seconds. If the 
            timeout expires, less than the desired number of streams 
            (possibly none) will be returned. (default FOREVER)
            
Returns a list of matching StreamInfo objects (with empty desc field), any 
of which can subsequently be used to open an inlet.

Example: results = resolve_Stream_byprop("type","EEG")

"""
function resolve_byprop(prop, value, minimum=1, timeout=FOREVER)
    buffer = Vector{Ptr{Void}}(1024) #(c_void_p*1024)()
    # num_found = lib.lsl_resolve_byprop(byref(buffer), 1024,
    #                                    c_char_p(str.encode(prop)),
    #                                    c_char_p(str.encode(value)),
    #                                    minimum,
    #                                    c_double(timeout))
    num_found = ccall((:lsl_resolve_byprop, LSLBIN), 
        Cint, 
        (Ptr{Ptr{Void}}, Cint, Cstring, Cstring, Cint, Cdouble),
        pointer(buffer), Cint(1024), prop, value, Cint(minimum), Cdouble(timeout)
    )
    [StreamInfo(handle=buffer[k]) for k in range(1,num_found)]
end

"""Resolve all streams that match a given predicate.

Advanced query that allows to impose more conditions on the retrieved 
streams; the given string is an XPath 1.0 predicate for the <description>
node (omitting the surrounding []"s), see also
http://en.wikipedia.org/w/index.php?title=XPath_1.0&oldid=474981951.

Keyword arguments:
* predicate -- The predicate string, e.g. "name="BioSemi"" or 
            "type="EEG" and starts-with(name,"BioSemi") and 
                count(description/desc/channels/channel)=32"
* minimum -- Return at least this many streams. (default 1)
* timeout -- Optionally a timeout of the operation, in seconds. If the 
            timeout expires, less than the desired number of streams 
            (possibly none) will be returned. (default FOREVER)
            
Returns a list of matching StreamInfo objects (with empty desc field), any 
of which can subsequently be used to open an inlet.

"""
function resolve_bypred(predicate, minimum=1, timeout=FOREVER)
    # noinspection PyCallingNonCallable
    # buffer = (c_void_p*1024)()
    buffer = Vector{Ptr{Void}}(1024) #(c_void_p*1024)()
    # num_found = lib.lsl_resolve_bypred(byref(buffer), 1024,
    #                                    c_char_p(str.encode(predicate)),
    #                                    minimum,
    #                                    c_double(timeout))
    num_found = ccall((:lsl_resolve_byprop, LSLBIN), 
        Cint, 
        (Ptr{Ptr{Void}}, Cuint, Cstring, Cint, Cdouble),
        pointer(buffer), Cuint(1024), predicate, Cint(minimum), Cdouble(wait_time)
    )
    return [StreamInfo(handle=buffer[k]) for k in range(1,num_found)]
end


# ====================
# === Memory functions
# ====================
function free_char_p_array_memory(char_p_array,num_elements)
    pointers = Ptr{Void}.(char_p_array) # the dot syntax for vectorizing functions
    for p in range(1,num_elements)
        if pointers[p] != nothing # only free initialized pointers
            # lib.lsl_destroy_string(pointers[p])
            ccall((:lsl_destroy_string, LSLBIN), Void, (Ptr{Void},), pointers[p] )
        end
    end
end

# ====================
# === Stream Inlet ===
# ====================
    
"""A stream inlet.

Inlets are used to receive streaming data (and meta-data) from the lab 
network.

"""
mutable struct StreamInlet{T, PS, PC}
    obj            # c_void_p(self.obj)
    channel_format # info.channel_format()
    channel_count  # info.channel_count()
    # do_pull_sample # fmt2pull_sample[self.channel_format]
    # do_pull_chunk  # fmt2pull_chunk[self.channel_format]
    # value_type     # fmt2type[self.channel_format]
    # sample_type    # self.value_type*self.channel_count
    sample_buf       # self.sample_type()
    buffers          # {}
end

"""Construct a new stream inlet from a resolved stream description.

Keyword arguments:

* description -- A resolved stream description object (as coming from one
        of the resolver functions). Note: the stream_inlet may also be
        constructed with a fully-specified stream_info, if the desired 
        channel format and count is already known up-front, but this is 
        strongly discouraged and should only ever be done if there is 
        no time to resolve the stream up-front (e.g., due to 
        limitations in the client program).
* max_buflen -- Optionally the maximum amount of data to buffer (in   
                seconds if there is a nominal sampling rate, otherwise 
                x100 in samples). Recording applications want to use a 
                fairly large buffer size here, while real-time 
                applications would only buffer as much as they need to 
                perform their next calculation. (default 360)
* max_chunklen -- Optionally the maximum size, in samples, at which 
                chunks are transmitted (the default corresponds to the 
                chunk sizes used by the sender). Recording programs  
                can use a generous size here (leaving it to the network 
                how to pack things), while real-time applications may 
                want a finer (perhaps 1-sample) granularity. If left 
                unspecified (=0), the sender determines the chunk 
                granularity. (default 0)
* recover -- Try to silently recover lost streams that are recoverable 
            (=those that that have a source_id set). In all other cases 
            (recover is False or the stream is not recoverable) 
            functions may throw a lost_error if the stream"s source is 
            lost (e.g., due to an app or computer crash). (default True)

"""
function StreamInlet(info_::StreamInfo ; max_buflen=360, max_chunklen=0, 
        recover=true, processing_flags=0)
    if typeof(info_) <: AbstractArray
        error("description needs to be of type StreamInfo, got a list.")
    end
    obj = ccall((:lsl_create_inlet, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cint, Cint, Cint),
        info_.obj, Cint(max_buflen), Cint(max_chunklen), Cint(recover)
    )
    obj = Ptr{Void}(obj)

    if obj == C_NULL
        error("could not create stream inlet.")
    end
    if processing_flags > 0
        # handle_error(lib.lsl_set_postprocessing(self.obj, processing_flags))
        handle_error(ccall((:lsl_set_postprocessing, LSLBIN), 
            Cint, (Cint,), Cint(processing_flags)))
    end
    
    channel_format_ = channel_format(info_)
    channel_count_  = channel_count(info_)
    do_pull_sample = fmt2pull_sample[channel_format_+1]
    do_pull_chunk  = fmt2pull_chunk[channel_format_+1]
    value_type     = fmt2type[channel_format_+1]
    # DRCFIX - do some subtype assertions on value_type and 
    # DRCFIX - do_pull_sample/do_pull_chunk to avoid red ink???
    # DRCNOTE, we can't use ctypes trick of multiplying basic type...
    # DRCNOTE, so value_type == sample_type, keeping both for now
    # sample_type    = value_type
    # sample         = Vector{value_type}(channel_count) # A buffer for a single sample for each channel
    buffers        = Dict() # DRCNOTE, this was a dictionary in python impl, copying that logic for now
    @show value_type
    @show do_pull_sample
    @show do_pull_chunk
    StreamInlet{value_type, do_pull_sample, do_pull_chunk}(
        obj,
        channel_format_,
        channel_count_,
        # do_pull_sample,
        # do_pull_chunk,
        # value_type,
        # sample_type,
        Vector{value_type}(channel_count_), # sample,
        buffers
    )
end

# DRCFIX should this be part of the "finalizer" logic for gc - that might have to be set in the constructor...
"""Destructor. The inlet will automatically disconnect if destroyed."""
function del(self::StreamInlet)
    # noinspection PyBroadException
    try
        # lib.lsl_destroy_inlet(self.obj)
        ccall((:lsl_destroy_inlet, LSLBIN), Void, (Ptr{Void},), self.obj)
    end
end
    
"""Retrieve the complete information of the given stream.

This includes the extended description. Can be invoked at any time of
the stream"s lifetime.

Keyword arguments:
* timeout -- Timeout of the operation. (default FOREVER)

Throws a TimeoutError (if the timeout expires), or LostError (if the 
stream source has been lost).

"""
function fullinfo(self::StreamInlet, timeout=FOREVER)
    # errcode = c_int()
    errcode = Cint(0)
    # result = lib.lsl_get_fullinfo(self.obj, c_double(timeout),
    #                                 byref(errcode))
    result = ccall((:lsl_get_fullinfo, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cdouble, Ptr{Cint}),
        self.obj, Cdouble(timeout), pointer(errcode) 
    )
    handle_error(errcode)
    return StreamInfo(handle=result)
end

"""Subscribe to the data stream.

All samples pushed in at the other end from this moment onwards will be 
queued and eventually be delivered in response to pull_sample() or 
pull_chunk() calls. Pulling a sample without some preceding open_stream 
is permitted (the stream will then be opened implicitly).

Keyword arguments:
* timeout -- Optional timeout of the operation (default FOREVER).

Throws a TimeoutError (if the timeout expires), or LostError (if the 
stream source has been lost).

"""
function open_stream(self::StreamInlet, timeout=FOREVER)
    errcode = Cint(0) # c_int()
    # lib.lsl_open_stream(self.obj, c_double(timeout), byref(errcode))
     # DRCFIX should all "self.obj" in this file be replaced with "Ptr{Void}(self.obj)" ???
    ccall((:lsl_open_stream, LSLBIN),
        Void,
        (Ptr{Void}, Cdouble, Ptr{Cint}),
        self.obj, Cdouble(timeout), pointer(errcode)
    )
    handle_error(errcode)
end
    
"""Drop the current data stream.

All samples that are still buffered or in flight will be dropped and 
transmission and buffering of data for this inlet will be stopped. If 
an application stops being interested in data from a source 
(temporarily or not) but keeps the outlet alive, it should call 
lsl_close_stream() to not waste unnecessary system and network 
resources.

"""
function close_stream(self::StreamInlet)
    # lib.lsl_close_stream(self.obj)
    ccall((:lsl_close_stream, LSLBIN), Void, (Ptr{Void},), self.obj)
end

"""Retrieve an estimated time correction offset for the given stream.

The first call to this function takes several miliseconds until a 
reliable first estimate is obtained. Subsequent calls are instantaneous 
(and rely on periodic background updates). The precision of these 
estimates should be below 1 ms (empirically within +/-0.2 ms).

Keyword arguments: 
* timeout -- Timeout to acquire the first time-correction estimate 
            (default FOREVER).
            
Returns the current time correction estimate. This is the number that 
needs to be added to a time stamp that was remotely generated via 
local_clock() to map it into the local clock domain of this 
machine.

Throws a TimeoutError (if the timeout expires), or LostError (if the 
stream source has been lost).

    """
function time_correction(self::StreamInlet, timeout=FOREVER)
    errcode = Cint(0) # c_int()
    # result = lib.lsl_time_correction(self.obj, c_double(timeout),
    #                                     byref(errcode))
    result = ccall((:lsl_time_correction, LSLBIN),
        Cdouble,
        (Ptr{Void}, Cdouble, Ptr{Cint}),
        self.obj, Cdouble(timeout), pointer(errcode)
    )
    handle_error(errcode)
    result
end
    
"""Pull a sample from the inlet and return it.

Keyword arguments:
* timeout -- The timeout for this operation, if any. (default FOREVER)
            If this is passed as 0.0, then the function returns only a 
            sample if one is buffered for immediate pickup.

Returns a tuple (sample,timestamp) where sample is a list of channel 
values and timestamp is the capture time of the sample on the remote 
machine, or (nothing,nothing) if no new sample was available. To remap this 
time stamp to the local clock, add the value returned by 
.time_correction() to it. 

Throws a LostError if the stream source has been lost. Note that, if 
the timeout expires, no TimeoutError is thrown (because this case is 
not considered an error).

"""
function pull_sample(self::StreamInlet{T}, timeout=FOREVER, 
        sample=nothing) where {T<:LSL_VALUE_TYPE_UNION}    
    # support for the legacy API
    # DRCFIX - does legacy api of "pull_sample" need to be supported???
    assign_to = nothing
    # if typeof(timeout) is list:
    #     assign_to = timeout
    #     timeout = sample if typeof(sample) is float else 0.0
    # else:
    #     assign_to = nothing
            
    errcode = Cint(0) # c_int()
    # timestamp = self.do_pull_sample(self.obj, byref(self.sample),
    #                                 self.channel_count, c_double(timeout),
    #                                 byref(errcode))
    # DRCNOTE, "self.sample" above is a C-compatiable buffer 
    # DRCNOTE, for holding self.channel_count values of type self.value_type
    timestamp = ccall((self.do_pull_sample, LSLBIN),
        Cdouble,
        (Ptr{Void}, Ptr{T}, Cint, Cdouble, Ptr{Cint}),
        self.obj, pointer(self.sample_buf), Cint(self.channel_count), 
            Cdouble(timeout), pointer(errcode)
    )
    handle_error(errcode)
    if timestamp
        # sample = [v for v in self.sample]
        sample = deepcopy(self.sample)
        # DRCFIX - ensure this string manipulation is unnecessary with Julia...
        # if self.channel_format == cf_string:
        #     sample = [v.decode("utf-8") for v in sample]
        # end
        # DRCFIX - does legacy api of "pull_sample" need to be supported???
        # if assign_to is not nothing:
        #     assign_to[:] = sample
        # end
        return sample, timestamp
    else
        return nothing, nothing
    end
end

"""Pull a chunk of samples from the inlet.

Keyword arguments:
* timeout -- The timeout of the operation; if passed as 0.0, then only 
            samples available for immediate pickup will be returned. 
            (default 0.0)
* max_samples -- Maximum number of samples to return. (default 
                1024)
* dest_obj -- A Python object that supports the buffer interface.
            If this is provided then the dest_obj will be updated in place
            and the samples list returned by this method will be empty.
            It is up to the caller to trim the buffer to the appropriate
            number of samples.
            A numpy buffer must be order="C"
            (default nothing)
# DRCFIX - in pull_chunk, what does 'A numpy buffer must be order="C"' imply for Julia impl ???
# DRCFIX - by default, I think Julia arrays are fortran order...
                
Returns a tuple (samples,timestamps) where samples is a list of samples 
(each itself a list of values), and timestamps is a list of time-stamps.

Throws a LostError if the stream source has been lost.

"""
function pull_chunk(self::StreamInlet{T}, timeout=0.0, 
    max_samples=1024, dest_obj=nothing) where {T<:LSL_VALUE_TYPE_UNION}
    # look up a pre-allocated buffer of appropriate length        
    num_channels = self.channel_count
    max_values = max_samples * num_channels

    if max_samples not in keys(self.buffers)
        # noinspection PyCallingNonCallable
        # self.buffers[max_samples] = ((self.value_type*max_values)(),
        #                                 (c_double*max_samples)())
        # DRCNOTE constructing 2-element Tuple here
        self.buffers[max_samples] = (
            Vector{T}(max_values), 
            Vector{Cdouble}(max_samples)
        )
    end
    if dest_obj != nothing
        # data_buff = (self.value_type * max_values).from_buffer(dest_obj)
        data_buff = dest_obj
    else
        data_buff = self.buffers[max_samples][1] # DRCNOTE changed idx from 0 to 1 b/c Python to Julia
    end
    ts_buff = self.buffers[max_samples][2] # DRCNOTE changed idx from 1 to 2 b/c Python to Julia

    # read data into it
    errcode = Cint(0) # c_int()
    # noinspection PyCallingNonCallable
    # num_elements = self.do_pull_chunk(self.obj, byref(data_buff),
    #                                     byref(ts_buff), max_values,
    #                                     max_samples, c_double(timeout),
    #                                     byref(errcode))
    num_elements = ccall((self.do_pull_chunk, LSLBIN),
        Culong,
        (Ptr{Void}, Ptr{T}, Ptr{Cdouble}, 
            Cint, Cint, Cdouble, Ptr{Cint} ),
        self.obj, pointer(data_buff), pointer(ts_buff),
            Cint(max_values), Cint(max_values), Cdouble(timeout), pointer(errcode)
    )
    handle_error(errcode)
    # return results (note: could offer a more efficient format in the 
    # future, e.g., a numpy array)
    num_samples = num_elements/num_channels
    if dest_obj == nothing
        samples = deepcopy(data_buff) # DRCNOTE deep copy seems correct here

        # DRCFIX - are the below shenaningans required for Julia impl?
        # DRCFIX - I'm wondering if Julia gc will obviate free_char_p_array_memory
        # samples = [[data_buff[s*num_channels+c] for c in range(1,num_channels)]
        #             for s in range(1,int(num_samples))]
        # if self.channel_format == cf_string:
        #     samples = [[v.decode("utf-8") for v in s] for s in samples]
        #     free_char_p_array_memory(data_buff, max_values)
        # end
    else
        samples = nothing
    end

    timestamps = [ts_buff[s] for s in range(1,Int(num_samples))]
    (samples, timestamps)
end
    
"""Query whether samples are currently available for immediate pickup.

Note that it is not a good idea to use samples_available() to determine 
whether a pull_*() call would block: to be sure, set the pull timeout 
to 0.0 or an acceptably low value. If the underlying implementation 
supports it, the value will be the number of samples available 
(otherwise it will be 1 or 0).

"""
function samples_available(self::StreamInlet)
    # return lib.lsl_samples_available(self.obj)
    ccall((:lsl_samples_available, LSLBIN), Cuint, (Ptr{Void},), self.obj )
end
    
"""Query whether the clock was potentially reset since the last call.

This is rarely-used function is only needed for applications that
combine multiple time_correction values to estimate precise clock
drift if they should tolerate cases where the source machine was
hot-swapped or restarted.

"""
function was_clock_reset(self::StreamInlet)
    # return bool(lib.lsl_was_clock_reset(self.obj))
    Bool(ccall((:lsl_was_clock_reset), 
        Cuint, 
        (Ptr{Void},),
        self.obj
    ))
end

# ===================
# === XML Element ===
# ===================

"""A lightweight XML element tree modeling the .desc() field of StreamInfo.

Has a name and can have multiple named children or have text content as 
value; attributes are omitted. Insider note: The interface is modeled after 
a subset of pugixml"s node type and is compatible with it. See also 
http://pugixml.googlecode.com/svn/tags/latest/docs/manual/access.html for 
additional documentation.

"""
mutable struct XMLElement
    e::Ptr{Void} # DRCFIX - force this to be Ptr{Void} at the struct level?
end

"""Construct new XML element from existing handle."""
function XMLElement(handle)
    XMLElement(Ptr{Void}(handle))
end

# === Tree Navigation ===

"""Get the first child of the element."""
function first_child(self::XMLElement)
    # return XMLElement(lib.lsl_first_child(self.e))
    XMLElement(ccall((:lsl_first_child, LSLBIN), Ptr{Void}, (Ptr{Void},), self.e))
end

"""Get the last child of the element."""
function last_child(self::XMLElement)
    # return XMLElement(lib.lsl_last_child(self.e))
    XMLElement(ccall((:lsl_last_child, LSLBIN), Ptr{Void}, (Ptr{Void},), self.e))
end

"""Get a child with a specified name."""
function child(self::XMLElement, name)
    # return XMLElement(lib.lsl_child(self.e, str.encode(name)))
    XMLElement(ccall((:lsl_child, LSLBIN), Ptr{Void}, (Ptr{Void},Cstring), self.e, name))
end

"""Get the next sibling in the children list of the parent node.

If a name is provided, the next sibling with the given name is returned.

"""
function next_sibling(self::XMLElement, name=nothing)
    if name == nothing
        return XMLElement(ccall((:lsl_next_sibling, LSLBIN), 
            Ptr{Void},
            (Ptr{Void},),
            self.e
        ))
    else
        return XMLElement(ccall((:lsl_next_sibling_n, LSLBIN),
            Ptr{Void},
            (Ptr{Void}, Cstring),
            self.e, name
        ))
    end
end

"""Get the previous sibling in the children list of the parent node.

If a name is provided, the previous sibling with the given name is
returned.

"""
function previous_sibling(self::XMLElement, name=nothing)
    if name == nothing
        return XMLElement(call((:lsl_previous_sibling, LSLBIN),
            Ptr{Void},
            (Ptr{Void},),
            self.e
        ))
    else
        return XMLElement(ccall((:lsl_previous_sibling_n, LSLBIN),
            Ptr{Void},
            (Ptr{Void}, Cstring),
            self.e, name
        ))
    end
end

"""Get the parent node."""
function parent(self::XMLElement)
    XMLElement(ccall((:lsl_parent, LSLBIN), Ptr{Void}, (Ptr{Void},), self.e))
end

# === Content Queries ===

"""Whether this node is empty."""
function empty(self::XMLElement)
    Bool(ccall((:lsl_empty, LSLBIN), Cint, (Ptr{Void},), self.e))
end

"""Whether this is a text body (instead of an XML element).

True both for plain char data and CData.

"""
function is_text(self::XMLElement)
    Bool(ccall((:lsl_is_text, LSLBIN), Cint, (Ptr{Void},), self.e))
end

"""Name of the element."""
function name(self::XMLElement)
    outp = ccall((:lsl_name, LSLBIN), Cstring, (Ptr{Void},), self.e)
    ptr2str(outp, funcname="lsl_name")
end

"""Value of the element."""
function value(self::XMLElement)
    outp = ccall((:lsl_value, LSLBIN), Cstring, (Ptr{Void},), self.e)
    ptr2str(outp, funcname="lsl_value")
end

"""Get child value (value of the first child that is text).

If a name is provided, then the value of the first child with the
given name is returned.

"""
function child_value(self::XMLElement, name=nothing)
    if name == nothing
        res = ccall((:lsl_child_value, LSLBIN), Cstring, (Ptr{Void},), self.e)
    else
        res = ccall((:lsl_child_value_n, LSLBIN), Cstring, (Ptr{Void}, Cstring), self.e, name)
    end
    ptr2str(res, "lsl_child_value")
end

# === Modification ===

# DRCFIX - should there be a ! (aka "bang") to the modifying methods of XMLElement, per Julia guidelines???
"""Append a child node with a given name, which has a (nameless) 
plain-text child with the given text value."""
function append_child_value(self::XMLElement, name, value)
    # return XMLElement(lib.lsl_append_child_value(self.e,
    #                                                 str.encode(name),
    #                                                 str.encode(value)))
    XMLElement(ccall((:lsl_append_child_value, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cstring, Cstring),
        self.e, name, value
    ))
end

"""Prepend a child node with a given name, which has a (nameless) 
plain-text child with the given text value."""
function prepend_child_value(self::XMLElement, name, value)
    XMLElement(ccall((:lsl_prepend_child_value, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cstring, Cstring),
        self.e, name, value
    ))
end

"""Set the text value of the (nameless) plain-text child of a named 
child node."""
function set_child_value(self::XMLElement, name, value)
    XMLElement(ccall((:lib.lsl_set_child_value, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cstring, Cstring),
        self.e, name, value
    ))
end

"""Set the element"s name. Returns False if the node is empty."""
function set_name(self::XMLElement, name)
    # return bool(lib.lsl_set_name(self.e, str.encode(name)))
    Bool(ccall((:lsl_set_name, LSLBIN), Cint, (Ptr{Void}, Cstring), self.e, "$(name)"))
end

"""Set the element"s value. Returns False if the node is empty."""
function set_value(self::XMLElement, value)
    Bool(ccall((:lsl_set_value, LSLBIN), Cint, (Ptr{Void}, Cstring), self.e, "$(value)"))
end

"""Append a child element with the specified name."""
function append_child(self::XMLElement, name)
    XMLElement(ccall((:lsl_append_child, LSLBIN), 
        Ptr{Void}, 
        (Ptr{Void}, Cstring),
        self.e, "$(name)"
    ))
end

"""Prepend a child element with the specified name."""
function prepend_child(self::XMLElement, name)
    XMLElement(ccall((:lsl_prepend_child, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Cstring),
        self.e, "$(name)"
    ))
end

"""Append a copy of the specified element as a child."""
function append_copy(self::XMLElement, elem::XMLElement)
    XMLElement(ccall((:lsl_append_copy, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Ptr{Void}),
        self.e, elem.e
    ))
end

"""Prepend a copy of the specified element as a child."""
function prepend_copy(self::XMLElement, elem::XMLElement)
    XMLElement(ccall((:lsl_prepend_copy, LSLBIN),
        Ptr{Void},
        (Ptr{Void}, Ptr{Void}),
        self.e, elem.e
    ))
end

"""Remove a given child element, specified by name or as element."""
function remove_child(self::XMLElement, rhs::XMLElement)
    ccall((:lsl_remove_child, LSLBIN), Void, (Ptr{Void}, Ptr{Void}), self.e, rhs.e)
end
function remove_child(self::XMLElement, rhs::AbstractString)
    ccall((:lsl_remove_child_n, LSLBIN), Void, (Ptr{Void}, Cstring), self.e, "$(rhs)")
end

            
# ==========================
# === ContinuousResolver ===
# ==========================
"""A convenience class resolving streams continuously in the background.

This object can be queried at any time for the set of streams that are
currently visible on the network.

"""
mutable struct ContinuousResolver
    obj
end
# DRCFIX - write Base.show(io::IO, m::MyType) function
# function Base.show(io::IO, m::MyType)
#     print(io, "$(typeof(m))($(join([x?'1':'0' for x in (rand(5).>0.5)])))")
# end

"""Construct a new continuous_resolver.

Keyword arguments:
* forget_after -- When a stream is no longer visible on the network       
                (e.g., because it was shut down), this is the time in 
                seconds after which it is no longer reported by the 
                resolver.

"""
function ContinuousResolver(prop=nothing, value=nothing, pred=nothing, forget_after=5.0)
    if pred != nothing
        if prop != nothing || value != nothing
            error("you can only either pass the prop/value " * 
                 "argument or the pred argument, but not both.")
        end
        obj = ccall((:lsl_create_continuous_resolver_bypred, LSLBIN),
            Ptr{Void},
            (Cstring, Cdouble),
            "$(pred)", Cdouble(forget_after)
        )
    elseif prop != nothing && value != nothing
        obj = ccall((:lsl_create_continuous_resolver_byprop, LSLBIN),
            Ptr{Void},
            (Cstring, Cstring, Cdouble),
            "$(prop)", "$(value)", Cdouble(forget_after)
        )
    elseif prop != nothing || value != nothing
        error("if prop is specified, then value must be " *
              "specified, too, and vice versa.")
    else
        obj = ccall((:lsl_create_continuous_resolver, LSLBIN),
            Ptr{Void},
            (Cdouble,),
            Cdouble(forget_after)
        )
    end

    obj = Ptr{Void}(obj)
    if obj != C_NULL
        error("could not create continuous resolver.") # raise RuntimeError
    end
end

"""Destructor for the continuous resolver."""
# DRCFIX finalizer
function del(self::ContinuousResolver)
    # noinspection PyBroadException
    try
        ccall((:lsl_destroy_continuous_resolver, LSLBIN), Void, (Ptr{Void},), self.obj)
    end
end

"""Obtain the set of currently present streams on the network.

Returns a list of matching StreamInfo objects (with empty desc
field), any of which can subsequently be used to open an inlet.

"""
function results(self::ContinuousResolver)
    # noinspection PyCallingNonCallable
    buffer = Vectr{Ptr{Void}}(1024) # c_void_p*1024)()
    num_found = ccall((:lsl_resolver_results, LSLBIN),
        Cint,
        (Ptr{Void}, Ptr{Ptr{Void}}), 
        self.obj, pointer(buffer), 1024
    )
    return [StreamInfo(handle=buffer[k]) for k in range(1,num_found)]
end


# =========================
# === Error Definitions ===            
# =========================

# DRCFIX - use specific Julia exceptions where appropriate

# # noinspection PyShadowingBuiltins
# class TimeoutError(RuntimeError):
#     # note: although this overrides the name of a built-in exception,
#     #       this API is retained here for compatiblity with the Python 2.x
#     #       version of pylsl
#     pass


# class LostError(RuntimeError):
#     pass


# class InvalidArgumentError(RuntimeError):
#     pass


# class InternalError(RuntimeError):
#     pass


"""Error handler function. Translates an error code into an exception."""
function handle_error(errcode)
    # if typeof(errcode) is c_int:
    #     errcode = errcode.value
    if errcode == 0
        # pass  # no error
    elseif errcode == -1
        error("the operation failed due to a timeout.") # raise TimeoutError
    elseif errcode == -2
        error("the stream has been lost.") # raise LostError
    elseif errcode == -3
        error("an argument was incorrectly specified.") # raise InvalidArgumentError
    elseif errcode == -4
        error("an internal error has occurred.") # raise InternalError
    elseif errcode < 0
        error("an unknown error has occurred.") # raise RuntimeError
    end
end


# =================================================        
# === Compatibility Interface for old pylsl API ===                   
# =================================================                   

# DRCNOTE - Julia impl should not worry about "old pylsls API"
# # set class aliases
# stream_info = StreamInfo
# stream_outlet = StreamOutlet
# stream_inlet = StreamInlet
# xml_element = XMLElement
# timeout_error = TimeoutError
# lost_error = LostError
# vectorf = vectord = vectorl = vectori = vectors = vectorc = vectorstr = list

# DRCFIX - fix this silliness w/ multiple dispatch...
# function resolve_stream(args...)
#     if length(args) == 0
#         return resolve_streams()
#     elseif typeof(args[1]) <: Union{Int, AbstractFloat}
#         return resolve_streams(args[1])
#     elseif typeof(args[1]) <: AbstractString
#         if length(args) == 1
#             return resolve_bypred(args[1])
#         elseif typeof(args[2]) <: Union{Int, AbstractFloat}
#             return resolve_bypred(args[1], args[2])
#         else
#             if length(args) == 2
#                 return resolve_byprop(args[1], args[2])
#             else
#                 return resolve_byprop(args[1], args[2], args[3])
#             end
#         end
#     end
# end

resolve_stream() = resolve_streams()
resolve_stream(arg1::Union{Int, AbstractFloat}) = resolve_streams(arg1)
resolve_stream(arg1::AbstractString) = resolve_bypred(arg1)
resolve_stream(arg1::AbstractString, arg2::Union{Int, AbstractFloat}) = resolve_bypred(arg1, arg2)
resolve_stream(arg1::AbstractString, arg2) = resolve_byprop(arg1, arg2)
resolve_byprop(arg1::AbstractString, arg2, arg3) = resolve_byprop(arg1, arg2, arg3)


# ==================================
# === Module Initialization Code ===
# ==================================

# DRCFIX, determine a strategy for automatically finding dll/so file
# DRCFIX, for now, just call set_lslbin

# # find and load library
# os_name = platform.system()
# bitness = 8 * struct.calcsize("P")
# if os_name in ["Windows", "Microsoft"]:
#     libname = "liblsl32.dll" if bitness == 32 else "liblsl64.dll"
# elif os_name == "Darwin":
#     libname = "liblsl32.dylib" if bitness == 32 else "liblsl64.dylib"
# elif os_name == "Linux":
#     libname = "liblsl32.so" if bitness == 32 else "liblsl64.so"
# else:
#     raise RuntimeError("unrecognized operating system:", os_name)
# libpath = os.path.join(os.path.dirname(__file__), libname)
# if not os.path.isfile(libpath):
#     libpath = util.find_library(libname)
# if not libpath:
#     raise RuntimeError("library " + libname + " was not found - make sure "
#                        "that it is on the search path (e.g., in the same "
#                        "folder as pylsl.py).")
# lib = CDLL(libpath)

# # DRCNOTE - setting return types and arg types is already done at each ccall above
# # set function return types where necessary
# lib.lsl_local_clock.restype = c_double
# lib.lsl_create_streaminfo.restype = c_void_p
# lib.lsl_get_name.restype = c_char_p
# lib.lsl_get_type.restype = c_char_p
# lib.lsl_get_nominal_srate.restype = c_double
# lib.lsl_get_source_id.restype = c_char_p
# lib.lsl_get_created_at.restype = c_double
# lib.lsl_get_uid.restype = c_char_p
# lib.lsl_get_session_id.restype = c_char_p
# lib.lsl_get_hostname.restype = c_char_p
# lib.lsl_get_desc.restype = c_void_p
# lib.lsl_get_xml.restype = c_char_p
# lib.lsl_create_outlet.restype = c_void_p
# lib.lsl_create_inlet.restype = c_void_p 
# lib.lsl_get_fullinfo.restype = c_void_p
# lib.lsl_open_stream.restype = c_void_p
# lib.lsl_time_correction.restype = c_double
# lib.lsl_pull_sample_f.restype = c_double
# lib.lsl_pull_sample_d.restype = c_double
# lib.lsl_pull_sample_l.restype = c_double
# lib.lsl_pull_sample_i.restype = c_double
# lib.lsl_pull_sample_s.restype = c_double
# lib.lsl_pull_sample_c.restype = c_double
# lib.lsl_pull_sample_str.restype = c_double
# lib.lsl_pull_sample_buf.restype = c_double
# lib.lsl_first_child.restype = c_void_p
# lib.lsl_first_child.argtypes = [c_void_p, ]
# lib.lsl_last_child.restype = c_void_p
# lib.lsl_last_child.argtypes = [c_void_p, ]
# lib.lsl_next_sibling.restype = c_void_p
# lib.lsl_next_sibling.argtypes = [c_void_p, ]
# lib.lsl_previous_sibling.restype = c_void_p
# lib.lsl_previous_sibling.argtypes = [c_void_p, ]
# lib.lsl_parent.restype = c_void_p
# lib.lsl_parent.argtypes = [c_void_p, ]
# lib.lsl_child.restype = c_void_p
# lib.lsl_child.argtypes = [c_void_p, c_char_p]
# lib.lsl_next_sibling_n.restype = c_void_p
# lib.lsl_next_sibling_n.argtypes = [c_void_p, c_char_p]
# lib.lsl_previous_sibling_n.restype = c_void_p
# lib.lsl_previous_sibling_n.argtypes = [c_void_p, c_char_p]
# lib.lsl_name.restype = c_char_p
# lib.lsl_name.argtypes = [c_void_p, ]
# lib.lsl_value.restype = c_char_p
# lib.lsl_value.argtypes = [c_void_p, ]
# lib.lsl_child_value.restype = c_char_p
# lib.lsl_child_value.argtypes = [c_void_p, ]
# lib.lsl_child_value_n.restype = c_char_p
# lib.lsl_child_value_n.argtypes = [c_void_p, c_char_p]
# lib.lsl_append_child_value.restype = c_void_p
# lib.lsl_append_child_value.argtypes = [c_void_p, c_char_p, c_char_p]
# lib.lsl_prepend_child_value.restype = c_void_p
# lib.lsl_prepend_child_value.argtypes = [c_void_p, c_char_p, c_char_p]
# # Return type for lsl_set_child_value, lsl_set_name, lsl_set_value is int
# lib.lsl_set_child_value.argtypes = [c_void_p, c_char_p, c_char_p]
# lib.lsl_set_name.argtypes = [c_void_p, c_char_p]
# lib.lsl_set_value.argtypes = [c_void_p, c_char_p]
# lib.lsl_append_child.restype = c_void_p
# lib.lsl_append_child.argtypes = [c_void_p, c_char_p]
# lib.lsl_prepend_child.restype = c_void_p
# lib.lsl_prepend_child.argtypes = [c_void_p, c_char_p]
# lib.lsl_append_copy.restype = c_void_p
# lib.lsl_append_copy.argtypes = [c_void_p, c_void_p]
# lib.lsl_prepend_copy.restype = c_void_p
# lib.lsl_prepend_copy.argtypes = [c_void_p, c_void_p]
# lib.lsl_remove_child_n.argtypes = [c_void_p, c_char_p]
# lib.lsl_remove_child.argtypes = [c_void_p, c_void_p]
# lib.lsl_destroy_string.argtypes = [c_void_p]
# # noinspection PyBroadException
# try:
#     lib.lsl_pull_chunk_f.restype = c_long
#     lib.lsl_pull_chunk_d.restype = c_long
#     lib.lsl_pull_chunk_l.restype = c_long
#     lib.lsl_pull_chunk_i.restype = c_long
#     lib.lsl_pull_chunk_s.restype = c_long
#     lib.lsl_pull_chunk_c.restype = c_long
#     lib.lsl_pull_chunk_str.restype = c_long
#     lib.lsl_pull_chunk_buf.restype = c_long
# except:
#     print("pylsl: chunk transfer functions not available in your liblsl "
#           "version.")
# # noinspection PyBroadException
# try:
#     lib.lsl_create_continuous_resolver.restype = c_void_p
#     lib.lsl_create_continuous_resolver_bypred.restype = c_void_p
#     lib.lsl_create_continuous_resolver_byprop.restype = c_void_p
# except:
#     print("pylsl: ContinuousResolver not (fully) available in your liblsl "
#           "version.")


