/* =============================================================================
 * FILE: monitor.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    The monitor is a silent security camera (passive observer). It has NO HANDS—
 *    it NEVER drives pins or changes wires. It simply watches the pins on every 
 *    clock tick. 
 *    Whenever it sees a successful write or read happen, it scribbles down what 
 *    occurred onto a new transaction card and sends it to the Scoreboard to be graded.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Look-but-don't-touch component (Passive component): A testbench module that 
 *      strictly reads wires and never drives them, ensuring it doesn't accidentally 
 *      mask bugs in the hardware.
 *    - Doing two jobs at once (`fork ... join`): Spawning parallel loops. We need 
 *      one loop watching the write clock, and a second loop watching the read clock.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare class `fifo_monitor` with parameter `DATA_WIDTH`.
 *    Step 2: Store handles to the virtual interface (`vif`) and output mailbox (`mon2scb`).
 *    Step 3: Write constructor `new` connecting the interface and mailbox.
 *    Step 4: Write `task run()` using `fork ... join` to launch two parallel loops:
 *            - Write Watcher Loop: Every `@(posedge vif.wr_clk)`, check if 
 *              `(vif.wr_en && !vif.wr_full)`. If true, create a new transaction, 
 *              record `tr.wr = 1` and `tr.wr_data = vif.wr_data`, then push to `mon2scb`.
 *            - Read Watcher Loop: Every `@(posedge vif.rd_clk)`, check if 
 *              `(vif.rd_en && !vif.rd_empty)`. If true, create a new transaction, 
 *              record `tr.rd = 1` and `tr.rd_data = vif.rd_data`, then push to `mon2scb`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    class my_monitor;
 *        virtual my_cable vif;
 *        mailbox #(my_trans) outbox;
 *
 *        task run();
 *            fork
 *                // Thread 1:
 *                forever begin
 *                    @(posedge vif.clk);
 *                    if (vif.enable) begin
 *                        my_trans tr = new();
 *                        tr.cargo_data = vif.data;
 *                        outbox.put(tr);
 *                    end
 *                end
 *            join
 *        endtask
 *    endclass
 *
 * 5. THIS PROJECT'S EXACT CHECKS (ASYNC FIFO)
 *    - Write condition: `if (vif.wr_en && !vif.wr_full)` on `wr_clk`.
 *    - Read condition: `if (vif.rd_en && !vif.rd_empty)` on `rd_clk`.
 *    - Read data sampling: Make sure to capture `tr.rd_data = vif.rd_data` when 
 *      a valid read occurs so the scoreboard can check it!
 * ============================================================================= */

`ifndef MONITOR_SV
`define MONITOR_SV

class fifo_monitor #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

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
            end
        join
    endtask
endclass

`endif