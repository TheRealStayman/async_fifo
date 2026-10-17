`ifndef TB_PKG_SV
`define TB_PKG_SV

package tb_pkg;
    `include "transaction.sv"
    `include "generator.sv"
    `include "driver.sv"
    `include "monitor.sv"
    `include "scoreboard.sv"
endpackage

`endif