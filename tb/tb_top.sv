/* =============================================================================
 * FILE: tb_top.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    `tb_top` is the master workbench (testbench top). It contains the physical 
 *    battery/power supply, the clock metronomes, the chip itself (DUT), and the 
 *    cable bundle (interface). It starts the clock ticking, resets the chip, 
 *    wakes up the software workers, and prints the final report card.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Time ruler (Timescale directive / ` `timescale 1ns/1ps `): Tells the 
 *      simulator that a delay of `#5` means 5 nanoseconds, rounded to picoseconds.
 *    - The chip being tested (Design Under Test / DUT): Your `async_fifo_top` module.
 *    - Launch background workers (Non-blocking spawn / `fork ... join_none`): 
 *      Starts tasks running concurrently in the background and immediately moves 
 *      on without waiting for them to finish.
 *    - Stop the simulation (`$finish`): Halts the simulator run.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Add `` `timescale 1ns/1ps `` and `import tb_pkg::*;`.
 *    Step 2: Declare clock and reset logic signals (`wr_clk`, `rd_clk`, `wr_rst_n`, `rd_rst_n`).
 *    Step 3: Create two clock generators using `always` blocks:
 *            - Write clock (e.g., 100 MHz $\rightarrow$ invert every 5 ns: `always #5 wr_clk = ~wr_clk;`).
 *            - Read clock (e.g., 40 MHz $\rightarrow$ invert every 12.5 ns: `always #12.5 rd_clk = ~rd_clk;`).
 *    Step 4: Instantiate the physical `fifo_if` interface.
 *    Step 5: Instantiate the `async_fifo_top` (DUT) and connect its pins to the interface.
 *    Step 6: Inside an `initial` block:
 *            - Construct the shared mailboxes (`gen2drv`, `mon2scb`).
 *            - Construct the 4 components (`gen`, `drv`, `mon`, `scb`).
 *            - Hold reset low for 40 ns, then set resets high (inactive).
 *            - Call `drv.reset()`.
 *            - Launch `drv.run()`, `mon.run()`, and `scb.run()` inside `fork ... join_none`.
 *            - Run the generator: `gen.run()`.
 *            - Wait `#500;` for leftover bytes to finish draining.
 *            - Print summary: check if `scb.error_count == 0` and display PASS/FAIL.
 *            - Call `$finish;`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    `timescale 1ns/1ps
 *    import tb_pkg::*;
 *
 *    module tb_top;
 *        logic clk = 0;
 *        always #5 clk = ~clk; // Clock generator
 *
 *        my_interface intf(clk);
 *        my_dut u_dut (.clk(intf.clk), .data(intf.data));
 *
 *        initial begin
 *            // 1. Build testbench
 *            // 2. Release reset
 *            // 3. fork drv.run(); mon.run(); scb.run(); join_none
 *            // 4. gen.run();
 *            // 5. Check scb.errors and $finish;
 *        end
 *    endmodule
 *
 * 5. THIS PROJECT'S EXACT TIMING (ASYNC FIFO)
 *    - Write clock: 100 MHz (`always #5 wr_clk = ~wr_clk;`)
 *    - Read clock: 40 MHz (`always #12.5 rd_clk = ~rd_clk;`)
 *    - Because the two clocks run at different speeds with independent phases, 
 *      this naturally stresses the clock domain crossing synchronizers!
 * ============================================================================= */

`timescale 1ns/1ps
import tb_pkg::*;

module tb_top;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;

    // Asymmetric Clocks: wr_clk = 100 MHz (10ns period), rd_clk = 40 MHz (25ns period)
    logic wr_clk = 0;
    logic rd_clk = 0;
    logic wr_rst_n = 0;
    logic rd_rst_n = 0;

    always #5   wr_clk = ~wr_clk;
    always #12.5 rd_clk = ~rd_clk;

    // Physical Interface Bundle
    fifo_if #(DATA_WIDTH) intf (
        .wr_clk   (wr_clk),
        .rd_clk   (rd_clk),
        .wr_rst_n (wr_rst_n),
        .rd_rst_n (rd_rst_n)
    );

    // Device Under Test (DUT)
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

    // Verification Mailboxes & Classes
    mailbox #(fifo_transaction#(DATA_WIDTH)) gen2drv = new();
    mailbox #(fifo_transaction#(DATA_WIDTH)) mon2scb = new();

    fifo_generator  #(DATA_WIDTH) gen;
    fifo_driver     #(DATA_WIDTH) drv;
    fifo_monitor    #(DATA_WIDTH) mon;
    fifo_scoreboard #(DATA_WIDTH) scb;

    initial begin
        gen = new(gen2drv, 2500);
        drv = new(intf, gen2drv);
        mon = new(intf, mon2scb);
        scb = new(mon2scb);

        // Apply Reset
        wr_rst_n = 0;
        rd_rst_n = 0;
        #40;
        wr_rst_n = 1;
        rd_rst_n = 1;
        drv.reset();

        // Launch Verification Threads
        fork
            drv.run();
            mon.run();
            scb.run();
        join_none

        // Run Stimulus Generation
        gen.run();

        // Drain pipeline
        #1000;

        // Print Results
        $display("\n========================================================");
        $display("                   SIMULATION RESULTS                   ");
        $display("========================================================");
        $display(" Total Matches: %0d", scb.match_count);
        $display(" Total Errors:  %0d", scb.error_count);
        $display(" Unread Items Remaining in Queue: %0d", scb.golden_queue.size());
        $display("========================================================");

        if (scb.error_count == 0 && scb.match_count > 0) begin
            $display(" STATUS: >>> TEST PASSED (NO CORRUPTION DETECTED) <<< \n");
        end else begin
            $display(" STATUS: >>> TEST FAILED <<< \n");
        end

        $finish;
    end
endmodule