# Replace "vlib work" in run.do with a clean wipe:
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL
vlog -sv -work work ../rtl/fifo_mem.sv
vlog -sv -work work ../rtl/sync_2ff.sv
vlog -sv -work work ../rtl/wptr_full.sv
vlog -sv -work work ../rtl/rptr_empty.sv
vlog -sv -work work ../rtl/async_fifo_top.sv

# Compile Interface and Testbench
vlog -sv -work work ../tb/fifo_if.sv
vlog -sv -work work +incdir+../tb ../tb/tb_pkg.sv
vlog -sv -work work ../tb/tb_top.sv

# Simulate
vsim -voptargs="+acc" work.tb_top
run -all