/* =============================================================================
 * FILE: driver.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    The driver is the hardware operator with hands on the control panel. It 
 *    pulls a digital note card (transaction) from the mailbox, looks at what it 
 *    says ("write byte 0xFF"), waits for the clock metronome to tick, and 
 *    physically presses the buttons and wiggles the wires on the chip interface.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Software cable handle (Virtual Interface / `vif`): The driver's pointer to 
 *      the physical wires of the chip.
 *    - Pulling from outbox (Mailbox `get`): Calling `box.get(tr)` pulls the next 
 *      note card out. If the box is empty, it waits patiently.
 *    - Wait for clock tick (`@(posedge clk)`): Pauses until the rising edge of 
 *      the clock occurs before doing something.
 *    - Glitch-free clock-edge driving (Non-blocking assignment / `<=`): Assigning 
 *      values to wires using `<=` so changes take effect cleanly on clock edges 
 *      without simulator race conditions.
 *    - Splitting workers into parallel tasks (Parallel processes / `fork ... join`): 
 *      Spawning two tasks at the exact same moment. 
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare class `fifo_driver` with parameter `DATA_WIDTH`.
 *    Step 2: Store handles to the virtual interface (`vif`) and the mailbox (`gen2drv`).
 *    Step 3: Write a constructor `new` connecting these handles from the testbench.
 *    Step 4: Write a `task reset()`: set all enable pins to 0, and wait until 
 *            the resets go high (inactive).
 *    Step 5: Write a `task run()`:
 *            - Loop forever: pull a card using `gen2drv.get(tr)`.
 *            - If `tr.wr` is 1: wait for `@(posedge vif.wr_clk)`. If the FIFO is 
 *              not full, drive `vif.wr_en <= 1` and `vif.wr_data <= tr.wr_data`. 
 *              Wait 1 clock edge, then turn `vif.wr_en <= 0`.
 *            - If `tr.rd` is 1: wait for `@(posedge vif.rd_clk)`. If the FIFO is 
 *              not empty, drive `vif.rd_en <= 1`. Wait 1 clock edge, then turn 
 *              `vif.rd_en <= 0`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    class my_driver;
 *        virtual my_cable vif;
 *        mailbox #(my_trans) box;
 *
 *        function new(virtual my_cable vif, mailbox #(my_trans) box);
 *            this.vif = vif;
 *            this.box = box;
 *        endfunction
 *
 *        task run();
 *            my_trans tr;
 *            forever begin
 *                box.get(tr); // Get next card
 *                @(posedge vif.clk);
 *                vif.enable <= tr.action_flag;
 *                vif.data   <= tr.cargo_data;
 *                @(posedge vif.clk);
 *                vif.enable <= 1'b0; // Turn off strobe
 *            end
 *        endtask
 *    endclass
 *
 * 5. THIS PROJECT'S EXACT LOGIC (ASYNC FIFO)
 *    - You are dealing with TWO clocks! 
 *    - Write actions must be synchronized to `@(posedge vif.wr_clk)`.
 *    - Read actions must be synchronized to `@(posedge vif.rd_clk)`.
 *    - Protect the FIFO: Only assert `wr_en` if `!vif.wr_full`. Only assert 
 *      `rd_en` if `!vif.rd_empty`.
 * ============================================================================= */

`ifndef DRIVER_SV
`define DRIVER_SV

class fifo_driver #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    virtual fifo_if #(DATA_WIDTH) vif;
    mailbox #(trans_t)            gen2drv;

    function new(virtual fifo_if #(DATA_WIDTH) vif, mailbox #(trans_t) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task reset();
        vif.wr_en   <= 1'b0;
        vif.wr_data <= '0;
        vif.rd_en   <= 1'b0;
        @(posedge vif.wr_rst_n);
        @(posedge vif.rd_rst_n);
        @(posedge vif.wr_clk);
        @(posedge vif.rd_clk);
    endtask

    task run();
        trans_t tr;
        forever begin
            gen2drv.get(tr);

            // Execute write branch on write-clock domain
            if (tr.wr) begin
                @(posedge vif.wr_clk);
                if (!vif.wr_full) begin
                    vif.wr_en   <= 1'b1;
                    vif.wr_data <= tr.wr_data;
                end
                @(posedge vif.wr_clk);
                vif.wr_en   <= 1'b0;
            end

            // Execute read branch on read-clock domain
            if (tr.rd) begin
                @(posedge vif.rd_clk);
                if (!vif.rd_empty) begin
                    vif.rd_en <= 1'b1;
                end
                @(posedge vif.rd_clk);
                vif.rd_en <= 1'b0;
            end
        end
    endtask
endclass

`endif