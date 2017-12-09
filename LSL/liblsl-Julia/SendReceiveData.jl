#include "../../../include/lsl_c.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

# /**
# * This example program offers an 8-channel stream, float-formatted, that resembles EEG data.
# * The example demonstrates also how per-channel meta-data can be specified using the description field of the streaminfo object.
# *
# * Note that the timer used in the send loop of this program is not particularly accurate.
# */

channels = ["C3","C4","Cz","FPz","POz","CPz","O1","O2"];

# int main(int argc, char* argv[]) {

t,c = Cint(0), Cint(0) #int t,c;					/* time point and channel index */
# lsl_streaminfo info;		/* out stream declaration object */
# lsl_xml_ptr desc, chn, chns;/* some xml element pointers */ 
# lsl_outlet outlet;			/* stream outlet */
starttime = Cdouble(0) #double starttime;			/* used for send timing */
cursample = Vector{Cfloat}(8); # float cursample[8];			/* the current sample */

# /* declare a new streaminfo (name: BioSemi, content type: EEG, 8 channels, 100 Hz, float values, some made-up device id (can also be empty) */
si = StreamInfo("BioSemi","EEG", 8, 100, cf_float32, "325wqer4354")

# /* add some meta-data fields to it */
# /* (for more standard fields, see https://github.com/sccn/xdf/wiki/Meta-Data) */
# desc = lsl_get_desc(info);
# lsl_append_child_value(desc,"manufacturer","BioSemi");
# chns = lsl_append_child(desc,"channels");
# for (c=0;c<8;c++) {
# 	chn = lsl_append_child(chns,"channel");
# 	lsl_append_child_value(chn,"label",channels[c]);
# 	lsl_append_child_value(chn,"unit","microvolts");
# 	lsl_append_child_value(chn,"type","EEG");
# }

# /* make a new outlet (chunking: default, buffering: 360 seconds) */
so = StreamOutlet(si,0,360)

# /* send data forever (note: this loop is keeping the CPU busy, normally one would sleep or yield here) */
print("Now sending data...\n");
@async begin
	starttime = time();
	while time() - starttime < 15
		mysample = rand(Cfloat, 8)
		# lsl_push_sample_f(outlet,cursample);
		push_sample(so, mysample)
		sleep(0.01)
	end
end

# """Example program to show how to read a multi-channel time series from LSL."""
# from pylsl import StreamInlet, resolve_stream

# first resolve an EEG stream on the lab network
println("looking for an EEG stream...")
streams = resolve_stream("type", "EEG")

# create a new inlet to read from the stream
inlet = StreamInlet(streams[1])
begin
	starttime = time()
	while time() - starttime < 15
		# get a new sample (you can also omit the timestamp part if you're not
		# interested in it)
		sample, timestamp = pull_sample(inlet)
		print(timestamp, sample)
	end
end


# /* we never get here, buy anyway */
# lsl_destroy_outlet(outlet);
