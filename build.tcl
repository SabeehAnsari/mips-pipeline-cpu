#=========================================================================
#  build.tcl  -  regenerate the Vivado project from source
#
#  Run from the repository root:
#     vivado -mode batch -source build.tcl
#
#  This exists so the .xpr never has to be committed. Delete the generated
#  project directory whenever it misbehaves and run this again.
#=========================================================================

set proj_name  "mips_pipeline"
set proj_dir   "./vivado_project"
set part       "xc7a35tcpg236-1"

file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force

add_files -fileset sources_1 [glob -nocomplain ./rtl/*.v]
add_files -fileset sim_1     [glob -nocomplain ./tb/*.v]

set_property include_dirs [file normalize ./rtl] [get_filesets sources_1]
set_property include_dirs [file normalize ./rtl] [get_filesets sim_1]

set_property file_type {Verilog Header} [get_files ./rtl/defines.vh]

puts ""
puts "Project created at $proj_dir"
puts "Set the testbench you want as simulation top, then Run Behavioral Simulation."
puts ""
