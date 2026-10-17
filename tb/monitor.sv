`ifndef MONITOR_SV
`define MONITOR_SV

class fifo_monitor #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    int cov_full_hits  = 0;
    int cov_empty_hits = 0;
    int cov_simul_rw   = 0;

    virtual fifo_if #(DATA_WIDTH) vif;
    mailbox #(trans_t)            mon2scb;

    function new(virtual fifo_if #(DATA_WIDTH) vif, mailbox #(trans_t) mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        fork
            // Passive Write Domain Watcher
            forever begin
                @(posedge vif.wr_clk);
                if (vif.wr_en && !vif.wr_full) begin
                    trans_t tr = new();
                    tr.wr      = 1'b1;
                    tr.rd      = 1'b0;
                    tr.wr_data = vif.wr_data;
                    tr.full    = vif.wr_full;
                    mon2scb.put(tr);
                end
                if (vif.wr_full) cov_full_hits++;
                if (vif.wr_en && !vif.wr_full && vif.rd_en && !vif.rd_empty) cov_simul_rw++;
            end

            // Passive Read Domain Watcher
            forever begin
                @(posedge vif.rd_clk);
                if (vif.rd_en && !vif.rd_empty) begin
                    trans_t tr = new();
                    tr.wr      = 1'b0;
                    tr.rd      = 1'b1;
                    tr.rd_data = vif.rd_data;
                    tr.empty   = vif.rd_empty;
                    mon2scb.put(tr);
                end
                if (vif.rd_empty) cov_empty_hits++;
            end
        join
    endtask
endclass

`endif