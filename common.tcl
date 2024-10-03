
# Time units are ns
# Freq units are MHz

# Abs path for all.

set r [file normalize [file dirname [info script]]/..]

########
# Settings


set double_precision true



set brd_cfgs [dict create \
	"ZedBoard" [dict create \
		brd_name "ZedBoard" \
		board_part "digilentinc.com:zedboard:part0:1.0" \
		part "xc7z020clg484-1" \
		part_family "xc7z" \
		max_f 464 \
	] \
	"Trenz_PCIe_Mobo" [dict create \
		brd_name "Trenz_PCIe_Mobo" \
		description "PCIe mobo: TEF1002-02 + 4x5cm SoM: TE0820-05-4AI21MI + ADC brd: EVAL-AD7960FMCZ" \
		board_part "trenz.biz:te0820_4cg_1i:part0:3.0" \
		part "xczu4cg-sfvc784-1-i" \
		part_family "xczu" \
		max_f 667 \
	] \
	"Zybo" [dict create \
		brd_name "Zybo" \
		board_part "digilentinc.com:zybo:part0:1.0" \
		part "xc7z010clg400-1" \
		part_family "xc7z" \
		max_f 464 \
	] \
]

######

proc select_brd {brd_name} {
	global brd_cfgs
	global brd_cfg
	set brd_cfg [dict get $brd_cfgs $brd_name]
}

proc from_brd_cfg {key} {
	global brd_cfg
	return [dict get $brd_cfg $key]
}

proc in_brd_cfg {key} {
	global brd_cfg
	return [dict exists $brd_cfg $key]
}

######


proc this_d {} {
	return [file normalize [file dirname [info script]]]/
}
proc rel_d {rel} {
	return [file normalize [file dirname [info script]]/$rel]
}


proc setup_xsa_name {flags} {
		
	global xsa_name
	global bd_name
	set xsa_name ${bd_name}__[from_brd_cfg brd_name]

	global VERSION_MAJOR
	global VERSION_MINOR
	if {[info exists VERSION_MAJOR]} {
		set xsa_name ${xsa_name}__v${VERSION_MAJOR}.${VERSION_MINOR}
	}
	
	foreach name $flags {
		eval global $name
		eval set value $$name
		# -- instead of =
		set xsa_name ${xsa_name}__${name}--${value}
	}

	puts xsa_name=$xsa_name
}

proc export_ip {} {
	global p
	ipx::package_project -root_dir $p -vendor user.org -library user \
		-taxonomy /UserIP -generated_files -import_files -set_current false
}

proc add_rtl {rtl_dirs} {
	set r [rel_d ../../]
	foreach rtl_dir $rtl_dirs {
		add_files -scan_for_includes -fileset sources_1 \
			[concat \
				[glob -nocomplain $r/rtl/$rtl_dir/*.vhd] \
				[glob -nocomplain $r/rtl/$rtl_dir/*.v] \
				[glob -nocomplain $r/rtl/$rtl_dir/*.sv] \
			]
	}
	set_property file_type {VHDL 2008} [get_files *.vhd]
}
proc add_tb {tb_dirs} {
	set r [rel_d ../../]
	foreach tb_dir $tb_dirs {
		add_files -scan_for_includes -fileset sim_1 \
			[concat \
				[glob -nocomplain $r/tb/$tb_dir/*.vhd] \
				[glob -nocomplain $r/tb/$tb_dir/*.v] \
				[glob -nocomplain $r/tb/$tb_dir/*.sv] \
			]
		add_files -fileset sim_1 -norecurse \
			[glob $r/tb/$tb_dir/*.wcfg]
	}
	set_property file_type {VHDL 2008} [get_files *.vhd]
}

proc add_single_ip {ip} {
	set r [rel_d ../../]
	global p
	global prj_name

	#puts "ip = $ip"
	regexp "$r/rtl/.*/(.*).ip.tcl" $ip -> name
	if { ! [info exists name] } {
		error "ip \"$ip\" is not *.ip.tcl file."
	} else {
		puts $name
		source $ip
		
		set ip_name "${name}_ip"
		set xci_d $p/work/$prj_name/$prj_name.srcs/sources_1/ip/$ip_name
		set xci $xci_d/$ip_name.xci
		# Turn off Out-of-Context builds.
		set_property generate_synth_checkpoint false [get_files $xci]
		generate_target all [get_files $xci]
	}
}

proc glob_ips {ip_dirs} {
	set r [rel_d ../../]
	
	set ips {}
	foreach ip_dir $ip_dirs {
		set ips [concat $ips [glob -nocomplain $r/rtl/$ip_dir/*.ip.tcl]]
	}
	#puts $ips
	
	return $ips
}

proc add_ip {ip_dirs} {
	set ips [glob_ips $ip_dirs]
	puts "ips = $ips"

	foreach ip $ips {
		add_single_ip $ip
	}
}

proc ctor_prj {} {
	global r
	global p
	global prj_name
	
	create_project $prj_name $p/work/$prj_name -force
	set_property target_language VHDL [current_project]

	set_property part [from_brd_cfg part] [current_project]
	if {[in_brd_cfg board_part]} {
		set_property board_part [from_brd_cfg board_part] [current_project]
	}

	# Update IP repo.
	set_property ip_repo_paths $r/prj/ [current_project]
	update_ip_catalog -rebuild
}

proc ctor_ip {} {
	global r
	global p
	global prj_name
	
	create_project $prj_name $p/work/$prj_name -force
	set_property target_language VHDL [current_project]

	#TODO If cannot find brd_cfg 
	#then error with cure to call setup of prj before.

	set_property part [from_brd_cfg part] [current_project]
	if {[in_brd_cfg board_part]} {
		set_property board_part [from_brd_cfg board_part] [current_project]
	}

	# Update IP repo.
	set_property ip_repo_paths $r/prj/ [current_project]
	update_ip_catalog -rebuild
}

proc after_ctor_bd {} {
	global p
	global prj_name
	global bd_name

	validate_bd_design -force
	save_bd_design

	set bd_dir $p/work/$prj_name/$prj_name.srcs/sources_1/bd/$bd_name
	set bd_file $bd_dir/${bd_name}.bd
	generate_target all [get_files $bd_file]
	add_files -norecurse $bd_dir/hdl/${bd_name}_wrapper.vhd
	set_property top ${bd_name}_wrapper [current_fileset]
}




proc run_impl {} {
	file mkdir reports

	# Launch synthesis.
	reset_run synth_1
	launch_runs synth_1
	wait_on_run synth_1

	# Report resource utulization and preliminary timing.
	open_run synth_1 -name netlist_1
	report_utilization -hierarchical \
		-file reports/synth_utilization.txt
	report_timing_summary -report_unconstrained \
		-file reports/synth_timing.txt

	# Launch implementation.
	reset_run impl_1
	launch_runs impl_1
	wait_on_run impl_1

	open_run impl_1
	report_utilization -hierarchical -file reports/impl_utilization.txt
	report_timing_summary -file reports/impl_timing.txt
	
}

proc print_timing_status { } {
	#foreach run [get_runs -filter IS_IMPLEMENTATION] {}
	set run_name impl_1
	puts $run_name
	set run [get_runs $run_name]
	set wns [get_property STATS.WNS $run]
	set whs [get_property STATS.WHS $run]
	set tns [get_property STATS.TNS $run]
	set ths [get_property STATS.THS $run]
	# All should not be negative.
	puts "WNS: $wns"
	puts "WHS: $whs"
	puts "TNS: $tns"
	puts "THS: $ths"
	set timing_pass true
	foreach clk [get_clocks] {
		set f_clk [expr 1000.0/[get_property PERIOD $clk]]
		puts "f_clk: $f_clk"
		set this_clk_pass [expr $wns >= 0]
		set new_f_clk [expr 1000.0/(1000.0/$f_clk - $wns)]
		if {$this_clk_pass} {
			puts "$clk timing passed."
			puts "$clk could increaced from $f_clk MHz to $new_f_clk MHz."
		} else {
			set timing_pass false
			puts "$clk timing failed!"
			puts "$clk should be decreaced from $f_clk MHz to $new_f_clk MHz."
		}
	}
	if {$timing_pass} {
		puts "PASS: Successful timing!"
	} else {
		puts "FAIL: Timing failed!"
	}
	return $timing_pass
}


set tune_f_max_iters 20

proc tune_init {} {
	# If already exists make backup.
	if {[file exists $p/tuning_reports]} {
		file delete -force $p/tuning_reports.backup
		file rename -force $p/tuning_reports $p/tuning_reports.backup
	}
	if {[file exists $p/tuning_logs]} {
		file delete -force $p/tuning_logs.backup
		file rename -force $p/tuning_logs $p/tuning_logs.backup
	}
}

proc tune_f {top {name "default"} {start_f_clk 1000}} {
	if {[dict exists $brd_cfg max_f]} {
		set start_f_clk [from_brd_cfg max_f]
	}
	
	set_property top $top [current_fileset]
	update_compile_order -fileset sources_1
	
	# Remove clock settings.
	global d
	set brd_name [from_brd_cfg brd_name]
	set prj_clk_xdc "$p/constraints/$brd_name/clk.xdc"
	#export_ip_user_files -of_objects  [get_files $prj_clk_xdc] -no_script -reset -force -quiet
	remove_files  -fileset constrs_1 $prj_clk_xdc
	set tune_clk_xdc $p/work/tune_clk.xdc
	set fd [open $tune_clk_xdc w]
	close $fd
	add_files -fileset constrs_1 $tune_clk_xdc
	
	file mkdir tuning_logs/$brd_name/$top
	set log [open tuning_logs/$brd_name/$top/$name.txt a+]
	
	set f_clk $start_f_clk

	global d tune_f_max_iters
	
	for {set iter 0} {$iter < $tune_f_max_iters} {incr iter} {
		puts $log "iter=$iter"
		
		# Doing elaboration, to have design opened, so we can change frequency.
		if {$iter == 0} {
			synth_design -rtl -name rtl_1
		}
		
		set T_clk_ns [expr 1000.0/$f_clk]
		set fd [open $tune_clk_xdc w]
		puts $fd "create_clock -period $T_clk_ns -name clk \[get_ports i_clk\]"
		close $fd
		puts $log "f_clk=$f_clk"
		flush $log

		run_impl
		
		global r
		exec $r/prj/common/extract_resources.jl \
			reports/impl_utilization.txt reports/resources.tsv
		
		
		# All should be >= 0.
		set min_v 0
		foreach n {WNS WHS} {
			set v [get_property STATS.$n [get_runs impl_1]]
			puts -nonewline $log "$n=$v	"
			if {$v < $min_v} {
				set min_v $v
			}
		}
		
		set n WPWS
		set fn $p/work/tuning_timing_summary.txt
		report_timing_summary -file $fn
		set fd [open $fn r]
		set s [read $fd]
		close $fd
		set sl [split $s \n]
		for {set li 0} {$li < [llength $sl]} {incr li} {
			set line [lindex $sl $li]
			#Design Timing Summary
			set ci_beg [string first $n $line]
			if {$ci_beg != -1} {
				set li_dash [expr $li + 1]
				set line_dash [lindex $sl $li_dash]
				set first_dash [string index $line_dash $ci_beg]
				set ci_end [string first " " $line_dash $ci_beg]
				set li_num [expr $li + 2]
				set line_num [lindex $sl [expr $li + 2]]
				set num [string range $line_num $ci_beg $ci_end]
				set v [string trim $num]
				puts -nonewline $log "$n=$v	"
				if {$v < $min_v} {
					set min_v $v
				}
				break
			}
		}
		
		foreach n {TNS THS TPWS} {
			set v [get_property STATS.$n [get_runs impl_1]]
			puts -nonewline $log "$n=$v	"
		}
		puts $log ""
		
		if {$min_v >= 0} {
			puts $log "FOUND FREQ! f_clk=$f_clk"
			break
		} else {
			# Setting new f.
			set f_clk [expr 1000.0/(1000.0/$f_clk - $min_v)]
		}
		
		flush $log
	}
	if {$iter == $tune_f_max_iters} {
		puts $log "FAIL: Max iter succeeded!"
	}
	
	close $log
	
	#TODO Under testing
	close_design
	close_design
	close_design
	
	
	# Return back clock settings.
	remove_files  -fileset constrs_1 $tune_clk_xdc
	add_files -fileset constrs_1 $prj_clk_xdc
	
	return $f_clk
}

proc tune__create_tbl {name} {
	global tbl_name
	global brd_name
	
	file mkdir tuning_reports/$brd_name
	set tbl_name "tuning_reports/$brd_name/$name.tsv"
	set tbl [open $tbl_name a+]
	# Header
	puts -nonewline $tbl "f"
	puts $tbl ""
	close $tbl
}

proc tune_fp__create_tbl {name} {
	global tbl_name
	global brd_name
	
	file mkdir tuning_reports/$brd_name
	set tbl_name "tuning_reports/$brd_name/$name.tsv"
	set tbl [open $tbl_name a+]
	# Header
	puts -nonewline $tbl "opt	"
	puts -nonewline $tbl "usage	"
	puts -nonewline $tbl "latency	"
	puts -nonewline $tbl "f"
	puts $tbl ""
	close $tbl
}

proc tune__single {args} {
	set f [tune_f $args]
	global tbl_name
	set tbl [open $tbl_name a+]
	puts -nonewline $tbl "$f"
	puts $tbl ""
	close $tbl
	
	global r
	exec $r/prj/common/extract_resources.jl \
		reports/impl_utilization.txt $tbl_name
}

proc tune_fp__one_step_in_walk {name opt usage latency} {
	set ip_name "${name}_ip"
	set pb "pb_${name}"
	
	set_property -dict [list \
		CONFIG.C_Optimization $opt \
		CONFIG.Maximum_Latency {false} \
		CONFIG.C_Mult_Usage $usage \
		CONFIG.C_Latency $latency \
	] [get_ips $ip_name]
	
	
	set name "$opt-$usage-$latency"
	set f [tune_f $pb $name]
	
	
	global tbl_name
	
	# Try to figure out number of columns.
	set tbl [open $tbl_name r]
	set s [read $tbl]
	close $tbl
	set sl [split $s \n]
	set N_cols 0
	puts "N_cols = $N_cols"
	set N_lines [llength $sl]
	if { $N_lines != 0 } {
		set header [lindex $sl 0]
		set N_cols [llength [split $header \t]]
	}
	
	set tbl [open $tbl_name a+]
	puts -nonewline $tbl "$opt	"
	puts -nonewline $tbl "$usage	"
	puts -nonewline $tbl "$latency	"
	puts -nonewline $tbl "$f"
	set more_tabs [expr $N_cols - 4]
	puts -nonewline $tbl [string repeat \t $more_tabs]
	puts $tbl ""
	close $tbl
	
	global r
	exec $r/prj/common/extract_resources.jl \
		reports/impl_utilization.txt $tbl_name
}

proc tune_fp__walk_latency {name opt usage max_latency {min_latency 1}} {
	for {set latency $min_latency} {$latency <= $max_latency} {incr latency} {
		tune_fp__one_step_in_walk $name $opt $usage $latency
	}
}

proc export_hw { target {workspace_name ""} } {
	global r
	global p
	global bd_name
	global prj_name
	global xsa_name
	if {$xsa_name == ""} {
		set xsa_name $bd_name
	}
	puts "xsa_name=$xsa_name"
	if {$workspace_name == ""} {
		set workspace_name $prj_name
	}
	puts "workspace_name=$workspace_name"
	
	set timing_pass [print_timing_status]
	if {$timing_pass} {
		#TODO Error if it is already done. Realy?? Test it.
		set b $p/work/$prj_name/$prj_name.runs/impl_1/${bd_name}_wrapper
		set bit_fn $b.bit
		if { ! [file exists $bit_fn] } {
			launch_runs impl_1 -to_step write_bitstream -jobs 4
			
			wait_on_run impl_1
		}

		if { $target == "linux" } {
			#TODO Not tested.
			write_hw_platform -fixed -include_bit -force -file \
				$r/../../SW/PetaLinux/Exported_HW/$xsa_name.xsa
		} elseif { $target == "fw" } {
			#write_hw_platform -fixed -include_bit -force -file \
			#	$r/FW/$workspace_name/Exported_HW/$xsa_name.xsa
			#TODO Smarter.
			write_hw_platform -fixed -include_bit -force -file \
				$r/../../../../../MWT_Share/Outputs/UWB/Projects/Strobo_Sampler_v2__Proto__Pseudo_Diff_on_PMOD/FPGA/FW/$workspace_name/Exported_HW/$xsa_name.xsa
			set ltx_fn $b.ltx
			if { [file exists $ltx_fn] } {
				#TODO Test when attach ILA.
				file copy -force \
					$ltx_fn \
					$r/FW/$workspace_name/Exported_HW/$xsa_name.ltx
			}
		} else {
			puts "Non existing target \"$target\"!"
		}
	}
}


proc select_tb {tb_name} {
	global r
	global prj_name
	set_property top $tb_name [get_filesets sim_1]
	set_property xsim.view $r/tb/$prj_name/$tb_name.wcfg [get_filesets sim_1]
}
