tlp-streamer/tlp-streamer.runs/impl_1/tlp_streamer.bit:
	vivado -mode tcl -source vivado_build.tcl -notrace tlp-streamer/tlp-streamer.xpr

install: tlp-streamer/tlp-streamer.runs/impl_1/tlp_streamer.bit
	openocd -f cfg/program_screamer.cfg