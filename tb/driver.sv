`ifndef DRIVER_SV
`define DRIVER_SV

class fifo_driver #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    virtual fifo_if #(DATA_WIDTH) vif;
    mailbox #(trans_t)            gen2drv_wr;
    mailbox #(trans_t)            gen2drv_rd;

    function new(virtual fifo_if #(DATA_WIDTH) vif, 
                 mailbox #(trans_t) gen2drv_wr, 
                 mailbox #(trans_t) gen2drv_rd);
        this.vif        = vif;
        this.gen2drv_wr = gen2drv_wr;
        this.gen2drv_rd = gen2drv_rd;
    endfunction

    task reset();
        vif.wr_en   <= 1'b0;
        vif.wr_data <= '0;
        vif.rd_en   <= 1'b0;
        wait (vif.wr_rst_n === 1'b1);
        wait (vif.rd_rst_n === 1'b1);
        @(posedge vif.wr_clk);
        @(posedge vif.rd_clk);
    endtask

    task drive_write();
        trans_t tr;
        int wr_count = 0;
        forever begin
            gen2drv_wr.get(tr);

            // Wait until the FIFO is not full on a rising clock edge
            @(posedge vif.wr_clk);
            while (vif.wr_full === 1'b1) begin
                vif.wr_en <= 1'b0;
                @(posedge vif.wr_clk);
            end

            // FIFO is ready right now: drive write enable and data
            vif.wr_en   <= 1'b1;
            vif.wr_data <= tr.wr_data;

            // Wait for the next rising clock edge where the DUT samples this write
            @(posedge vif.wr_clk);
            vif.wr_en   <= 1'b0;

            // Occasionally pause writing (5% chance) so the slower read clock can drain the FIFO to EMPTY mid-test
            if ($urandom_range(1, 100) <= 5) begin
                repeat (40) @(posedge vif.wr_clk);
            end

            wr_count++;
            if (wr_count % 200 == 0) begin
                $display("[%0t ns] [DRV_WR] Completed write #%0d", $time, wr_count);
            end
        end
    endtask

    task drive_read();
        trans_t tr;
        int rd_count = 0;
        forever begin
            gen2drv_rd.get(tr);

            // Wait until the FIFO is not empty on a rising clock edge
            @(posedge vif.rd_clk);
            while (vif.rd_empty === 1'b1) begin
                vif.rd_en <= 1'b0;
                @(posedge vif.rd_clk);
            end

            // FIFO has data right now: drive read enable
            vif.rd_en <= 1'b1;

            // Wait for the next rising clock edge where the DUT processes this read
            @(posedge vif.rd_clk);
            vif.rd_en <= 1'b0;

            // Occasionally pause reading (5% chance) so the FIFO slams back to FULL
            if ($urandom_range(1, 100) <= 5) begin
                repeat (15) @(posedge vif.rd_clk);
            end

            rd_count++;
            if (rd_count % 200 == 0) begin
                $display("[%0t ns] [DRV_RD] Completed read #%0d", $time, rd_count);
            end
        end
    endtask

    task run();
        fork
            drive_write();
            drive_read();
        join
    endtask
endclass

`endif