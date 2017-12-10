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
starttime = time();

t = time()
f = 20.0;
while t - starttime < 15
    t = time()
    mysample = sin.(2*pi*f*t*ones(Cfloat,8))

    # lsl_push_sample_f(outlet,cursample);

    println("Pushing a sample: $mysample")
    push_sample(so, mysample)
    sleep(0.01)
end

