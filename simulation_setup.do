# Author Marko Jalonen
# Compile the VHDL source and start the simulator

vcom -check_synthesis ../vhd/
vsim -voptargs=+acc work.
view objects
view locals
view source
view wave -undock
delete wave *
add wave *
