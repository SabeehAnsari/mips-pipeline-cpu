#=========================================================================
#  synth.tcl  -  synthesise both CPUs and report Fmax and area
#
#  Run from the repository root:
#
#      vivado -mode batch -source synth.tcl
#
#  or from inside the Vivado GUI:  Tools -> Run Tcl Script...
#
#  It builds each CPU separately, runs synthesis, and writes the timing
#  and utilisation reports into synth_reports/. Takes a few minutes.
#
#  WHY THE INIT_FILE GENERIC MATTERS
#  ---------------------------------
#  imem defaults to INIT_FILE = "", which leaves the instruction memory
#  filled with zeros. Synthesis then sees a constant instruction word,
#  constant-folds the decoder, the ALU and the register file, and deletes
#  almost the entire CPU. The reported area collapses to a handful of
#  cells and the timing report is meaningless.
#
#  So we load a real program into the ROM before synthesising. The same
#  program is used for both designs, so the comparison stays fair.
#=========================================================================

set root [file dirname [file normalize [info script]]]
set part "xc7a35tcpg236-1"
set period 10.000
set hex [file join $root tests 05_hazards.hex]

if {![file exists $hex]} {
    puts "ERROR: program not found: $hex"
    puts "Synthesis without it would optimise the whole CPU away."
    return
}

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
    set_property generic "INIT_FILE=\"$hex\"" [current_fileset]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    open_run synth_1 -name netlist_$top

    set rpt [file join $root synth_reports $top]
    report_timing_summary  -file ${rpt}_timing.rpt
    report_utilization     -file ${rpt}_utilization.rpt

    set wns  [get_property SLACK [get_timing_paths -delay_type max]]
    set fmax [expr {1000.0 / ($period - $wns)}]
    set luts [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set ffs  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set brams [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]

    #  Sanity check: a CPU that synthesised properly cannot be this small.
    if {$luts < 100} {
        puts "\n  *** WARNING: only $luts LUTs. The design was optimised away."
        puts "  *** The instruction ROM is probably still empty. Check that"
        puts "  *** $hex loaded, and that imem's INIT_FILE generic took.\n"
    }

    puts "\n-------------------------------------------------------"
    puts "  $top"
    puts "    program loaded       [file tail $hex]"
    puts "    constrained period   $period ns"
    puts "    worst negative slack [format %.3f $wns] ns"
    puts "    Fmax                 [format %.1f $fmax] MHz"
    puts "    LUTs                 $luts"
    puts "    flip-flops           $ffs"
    puts "    block RAM            $brams"
    puts "-------------------------------------------------------\n"

    close_project
}

puts "\nReports written to synth_reports/"
puts "Record Fmax, LUTs and flip-flops for both designs.\n"
