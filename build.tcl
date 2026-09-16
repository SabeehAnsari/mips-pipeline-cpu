#=========================================================================
#  build.tcl  -  regenerate the Vivado project from source
#
#  From the Vivado GUI:   Tools -> Run Tcl Script...  -> pick this file
#  From a terminal:       vivado -mode batch -source build.tcl
#
#  This exists so the .xpr never has to be committed. If the project ever
#  misbehaves, delete vivado_project/ and run this again.
#
#  To change which testbench runs, either edit SIM_TOP below and re-run,
#  or in the GUI right-click the testbench in the Sources panel and choose
#  "Set as Top".
#=========================================================================

set SIM_TOP "alu_tb"

# anchor every path to this script's own directory, so it does not matter
# where Vivado was launched from
set root [file dirname [file normalize [info script]]]

set proj_name "mips_pipeline"
set proj_dir  [file join $root vivado_project]
set part      "xc7a35tcpg236-1"

if {[file exists $proj_dir]} { file delete -force $proj_dir }
create_project $proj_name $proj_dir -part $part -force

#---------------------------------------------------------------- sources
set rtl_files [glob -nocomplain [file join $root rtl *.v]]
set tb_files  [glob -nocomplain [file join $root tb  *.v]]

if {[llength $rtl_files] > 0} { add_files -fileset sources_1 $rtl_files }
if {[llength $tb_files]  > 0} { add_files -fileset sim_1     $tb_files }

# defines.vh is an include file, not a compilable source
set vh [file join $root rtl defines.vh]
if {[file exists $vh]} {
    add_files -fileset sources_1 $vh
    set_property file_type {Verilog Header} [get_files $vh]
}

# both filesets must be able to find defines.vh
set_property include_dirs [file join $root rtl] [get_filesets sources_1]
set_property include_dirs [file join $root rtl] [get_filesets sim_1]

#------------------------------------------------------------ simulation
set_property top $SIM_TOP [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

puts ""
puts "============================================================"
puts " Project created:   $proj_dir"
puts " Simulation top:    $SIM_TOP"
puts ""
puts " Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts " Then read the Tcl Console for the pass/fail summary."
puts "============================================================"
puts ""
