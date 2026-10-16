if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv -work work ../rtl/fifo_mem.sv
vlog -sv -work work ../rtl/sync_2ff.sv
vlog -sv -work work ../rtl/wptr_full.sv
vlog -sv -work work ../rtl/rptr_empty.sv
vlog -sv -work work ../rtl/async_fifo_top.sv
vlog -sv -work work ../tb/fifo_if.sv
vlog -sv -work work +incdir+../tb ../tb/tb_pkg.sv
vlog -sv -work work ../tb/tb_top.sv

vsim -voptargs="+acc" work.tb_top

# Group signals cleanly in the Waveform Viewer
add wave -divider "WRITE DOMAIN (100 MHz)"
add wave -radix hex /tb_top/dut/wr_clk
add wave -radix hex /tb_top/dut/wr_rst_n
add wave -radix hex /tb_top/dut/wr_en
add wave -radix hex /tb_top/dut/wr_data
add wave -radix hex /tb_top/dut/wr_full
add wave -radix binary /tb_top/dut/wgray

add wave -divider "READ DOMAIN (40 MHz)"
add wave -radix hex /tb_top/dut/rd_clk
add wave -radix hex /tb_top/dut/rd_rst_n
add wave -radix hex /tb_top/dut/rd_en
add wave -radix hex /tb_top/dut/rd_data
add wave -radix hex /tb_top/dut/rd_empty
add wave -radix binary /tb_top/dut/rgray

run -all
wave zoom full