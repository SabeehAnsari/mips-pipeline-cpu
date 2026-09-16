#=========================================================================
#  synth.tcl  -  synthesise both CPUs and report Fmax and area
#
#  Run from the repository root, with Vivado closed:
#
#      vivado -mode batch -source synth.tcl
#
#  or from inside the Vivado GUI:  Tools -> Run Tcl Script...
#
#  It builds each CPU separately, runs synthesis, and writes the timing
#  and utilisation reports into synth_reports/. Takes a few minutes.
#=========================================================================

set root [file dirname [file normalize [info script]]]
set part "xc7a35tcpg236-1"
set period 10.000

file mkdir [file join $root synth_reports]

foreach top {cpu_single cpu_pipelined} {

    puts "\n=================  synthesising $top  =================\n"

    set pdir [file join $root synth_$top]
    if {[file exists $pdir]} { file delete -force $pdir }
    create_project synth_$top $pdir -part $part -force

    add_files [glob [file join $root rtl *.v]]
    add_files -fileset constrs_1 [file join $root constraints.xdc]
    set_property file_type {Verilog Header} [get_files [file join $root rtl defines.vh]]
    set_property include_dirs [file join $root rtl] [get_filesets sources_1]
    set_property top $top [current_fileset]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    open_run synth_1 -name netlist_$top

    set rpt [file join $root synth_reports $top]
    report_timing_summary  -file ${rpt}_timing.rpt
    report_utilization     -file ${rpt}_utilization.rpt

    set wns [get_property SLACK [get_timing_paths -delay_type max]]
    set fmax [expr {1000.0 / ($period - $wns)}]

    puts "\n-------------------------------------------------------"
    puts "  $top"
    puts "    constrained period   $period ns"
    puts "    worst negative slack [format %.3f $wns] ns"
    puts "    Fmax                 [format %.1f $fmax] MHz"
    puts "    LUTs                 [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]"
    puts "    flip-flops           [llength [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]"
    puts "    block RAM            [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]"
    puts "-------------------------------------------------------\n"

    close_project
}

puts "\nReports written to synth_reports/"
puts "Record Fmax, LUTs and flip-flops for both designs.\n"
