
###############################################################################

source setup.tcl

# Pack IPs.
#source $r/prj/ip__strobo_clk/ctor_ip.tcl

#source setup.tcl

###############################################################################

ctor_prj

# Create boards.
source ./bd/strobo_sampler.tcl
after_ctor_bd

# Add constraints. TODO this is hardcoded for zybo only
add_files -fileset constrs_1 \
    ./bd/pins/zybo/pins.xdc


update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

###############################################################################
