# first resolve an EEG stream on the lab network
println("looking for an EEG stream...")
streams = resolve_byprop("type", "EEG", 1, 10.0)

println("Found a stream!")

# create a new inlet to read from the stream
inlet = StreamInlet(streams[1])
println("Made an inlet!")

begin
	starttime = time()
	while time() - starttime < 15
		# get a new sample (you can also omit the timestamp part if you're not
		# interested in it)
		println("Pulling a sample???")
        sample, timestamp = pull_sample(inlet, 1.0)
        println("Pulled: $sample")
		# println(timestamp, sample)
	end
end


# /* we never get here, buy anyway */
# lsl_destroy_outlet(outlet);
