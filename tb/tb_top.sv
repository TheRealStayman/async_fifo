`timescale 1ns/1ps
import tb_pkg::*;

module tb_top;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;

    // Asymmetric Clocks: wr_clk = 100 MHz (10ns), rd_clk = 40 MHz (25ns)
    logic wr_clk = 0;
    logic rd_clk = 0;
    logic wr_rst_n = 0;
    logic rd_rst_n = 0;

    real wr_half_period = 5.0;   // Starts at 100 MHz (10ns period)
    real rd_half_period = 12.5;  // Starts at 40 MHz  (25ns period)

    always #(wr_half_period) wr_clk = ~wr_clk;
    always #(rd_half_period) rd_clk = ~rd_clk;

    fifo_if #(DATA_WIDTH) intf (
        .wr_clk   (wr_clk),
        .rd_clk   (rd_clk),
        .wr_rst_n (wr_rst_n),
        .rd_rst_n (rd_rst_n)
    );

    async_fifo_top #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .wr_clk   (intf.wr_clk),
        .wr_rst_n (intf.wr_rst_n),
        .wr_en    (intf.wr_en),
        .wr_data  (intf.wr_data),
        .wr_full  (intf.wr_full),

        .rd_clk   (intf.rd_clk),
        .rd_rst_n (intf.rd_rst_n),
        .rd_en    (intf.rd_en),
        .rd_data  (intf.rd_data),
        .rd_empty (intf.rd_empty)
    );

    // Two independent mailboxes for concurrent CDC stimulation
    mailbox #(fifo_transaction#(DATA_WIDTH)) gen2drv_wr = new();
    mailbox #(fifo_transaction#(DATA_WIDTH)) gen2drv_rd = new();
    mailbox #(fifo_transaction#(DATA_WIDTH)) mon2scb    = new();

    fifo_generator  #(DATA_WIDTH) gen;
    fifo_driver     #(DATA_WIDTH) drv;
    fifo_monitor    #(DATA_WIDTH) mon;
    fifo_scoreboard #(DATA_WIDTH) scb;

    initial begin
        // Watchdog: 100 us (1000 reads at 40MHz = 25ns * 2 cycles * 1000 = 50,000ns)
        fork
            begin
                #250000;
                $display("\n[%0t ns] [WATCHDOG] Simulation timed out!", $time);
                $display("   Mailbox WR left: %0d | Mailbox RD left: %0d", gen2drv_wr.num(), gen2drv_rd.num());
                $display("   wr_full = %0b, rd_empty = %0b", intf.wr_full, intf.rd_empty);
                $display("   Scoreboard Matches: %0d, Errors: %0d", scb.match_count, scb.error_count);
                $display("   Golden Queue size: %0d", scb.golden_queue.size());
                $finish;
            end
        join_none

        $display("[%0t ns] [TB] Starting initialization...", $time);
        gen = new(gen2drv_wr, gen2drv_rd, 1000);
        drv = new(intf, gen2drv_wr, gen2drv_rd);
        mon = new(intf, mon2scb);
        scb = new(mon2scb);

        // Reset Sequence
        wr_rst_n = 0;
        rd_rst_n = 0;
        #40;
        wr_rst_n = 1;
        rd_rst_n = 1;
        drv.reset();
        $display("[%0t ns] [TB] Reset complete.", $time);

        // Launch background verification threads
        fork
            drv.run();
            mon.run();
            scb.run();
        join_none

        // Run Generator to load mailboxes
        $display("[%0t ns] [TB] Running generator...", $time);
        gen.run();
        $display("[%0t ns] [TB] Generator finished generating 1000 operations.", $time);

        // =====================================================================
        // DUAL-REGIME CLOCKED DRAINAGE SEQUENCE
        // =====================================================================
        
        // Phase 1: First 500 writes run with Fast Write (100 MHz) / Slow Read (40 MHz)
        // Stresses wr_full
        while (gen2drv_wr.num() > 500) begin
            @(posedge wr_clk);
        end
        $display("[%0t ns] [TB] 500 writes left. Swapping clocks to Slow Write (40 MHz) / Fast Read (100 MHz)!", $time);
        
        // Swap clock frequencies on the fly!
        wr_half_period = 12.5; // Slow down Write to 40 MHz
        rd_half_period = 5.0;  // Speed up Read to 100 MHz

        // Phase 2: Remaining 500 writes run with Slow Write / Fast Read
        // Stresses rd_empty
        while (gen2drv_wr.num() > 0) begin
            @(posedge wr_clk);
        end
        $display("[%0t ns] [TB] All write transactions driven.", $time);

        // 3. Poll on rd_clk until read mailbox is empty and scoreboard matches all 1000 items
        while (gen2drv_rd.num() > 0 || scb.golden_queue.size() > 0) begin
            @(posedge rd_clk);
        end
        $display("[%0t ns] [TB] All read transactions completed and verified.", $time);

        // Settle final clock edges
        #500;

        // Print final status
        $display("\n========================================================");
        $display("                   SIMULATION RESULTS                   ");
        $display("========================================================");
        $display(" Total Matches:              %0d", scb.match_count);
        $display(" Total Errors:               %0d", scb.error_count);
        $display(" Remaining in Golden Queue:  %0d", scb.golden_queue.size());
        $display("--------------------------------------------------------");
        $display(" CORNER-CASE COVERAGE:");
        $display("   FIFO Full States Hit:     %0d cycles", mon.cov_full_hits);
        $display("   FIFO Empty States Hit:    %0d cycles", mon.cov_empty_hits);
        $display("   Simultaneous R/W Cycles:  %0d cycles", mon.cov_simul_rw);
        $display("========================================================");

        if (scb.error_count == 0 && scb.match_count == 1000) begin
            $display(" STATUS: >>> TEST PASSED (1000/1000 VERIFIED, 0 ERRORS) <<< \n");
        end else begin
            $display(" STATUS: >>> TEST FAILED <<< \n");
        end

        $finish;
    end
endmodule