#=========================================================================
#  constraints.xdc  -  timing constraints for synthesis
#
#  The only thing that matters for the report is the clock. Everything
#  else in this file exists so that Vivado does not complain about
#  unconstrained ports and refuse to finish.
#
#  HOW TO FIND FMAX
#
#  Synthesis does not tell you the maximum frequency directly. It tells
#  you the WORST NEGATIVE SLACK against whatever period you asked for.
#
#      Fmax = 1 / (period - WNS)
#
#  So constrain at 10 ns, read WNS from the timing report, and compute.
#  A positive WNS means the design is faster than 10 ns; negative means
#  slower. Either way the formula holds.
#
#  Example: period 10 ns, WNS +2.5 ns -> 1 / 7.5 ns = 133 MHz
#           period 10 ns, WNS -4.0 ns -> 1 / 14.0 ns = 71 MHz
#
#  Use the SAME period for both CPUs so the comparison is fair.
#=========================================================================

create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# The debug ports are not pins on a real board. Give them a nominal
# delay so the tool has something to analyse, and relax the I/O
# placement check, which only matters when generating a bitstream.
set_input_delay  -clock sys_clk 1.000 [get_ports rst]
set_output_delay -clock sys_clk 1.000 [get_ports {debug_pc[*]}]
set_output_delay -clock sys_clk 1.000 [get_ports {debug_wr_data[*]}]

set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
