/* =============================================================================
 * FILE: scoreboard.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    The scoreboard is the teacher with an answer key (Reference Model / Golden Queue). 
 *    It receives reports from the security camera (monitor). 
 *    - When the monitor reports: "The driver just wrote 0x42 into the FIFO," 
 *      the scoreboard writes 0x42 down on its own perfect scratchpad list.
 *    - When the monitor reports: "The chip just read out 0x42," the scoreboard 
 *      checks its scratchpad. If the numbers match, it gives a green checkmark; 
 *      if they differ or the list was empty, it screams an error!
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Ideal answer key list (Reference Queue / `queue[$]`): A standard software list 
 *      that can grow indefinitely. We use `push_back()` to add items and 
 *      `pop_front()` to remove items in order.
 *    - Exact comparison including uninitialized states (Case inequality / `!==`): 
 *      Comparing values strictly. If the hardware outputs an uninitialized or 
 *      floating wire (`X` or `Z`), `!==` catches it as an error.
 *    - Reporting an error (`$error`): A system command that highlights a line in 
 *      red in the simulator console to flag a bug.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare class `fifo_scoreboard` with parameter `DATA_WIDTH`.
 *    Step 2: Declare an input mailbox (`mon2scb`), a reference queue 
 *            (`bit [DATA_WIDTH-1:0] golden_queue[$]`), and two counters: 
 *            `match_count` and `error_count`.
 *    Step 3: Write constructor `new` connecting the mailbox handle.
 *    Step 4: Write `task run()`:
 *            - Loop forever: `mon2scb.get(tr)`.
 *            - If `tr.wr`: push data onto back of queue (`golden_queue.push_back(tr.wr_data)`).
 *            - If `tr.rd`:
 *              * Check if `golden_queue.size() == 0`. If so, print an Underflow Error!
 *              * Otherwise, pop the expected byte: `expected = golden_queue.pop_front()`.
 *              * Compare: if `tr.rd_data !== expected`, flag `$error` and increment `error_count`.
 *              * Else, increment `match_count`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    class my_scoreboard;
 *        mailbox #(my_trans) inbox;
 *        bit [7:0] cheat_sheet[$]; // Software queue
 *        int matches = 0, errors = 0;
 *
 *        task run();
 *            my_trans tr;
 *            forever begin
 *                inbox.get(tr);
 *                if (tr.is_write) begin
 *                    cheat_sheet.push_back(tr.data);
 *                end
 *                if (tr.is_read) begin
 *                    bit [7:0] expected = cheat_sheet.pop_front();
 *                    if (tr.data !== expected) begin
 *                        $error("Mismatch! Got %h, expected %h", tr.data, expected);
 *                        errors++;
 *                    end else begin
 *                        matches++;
 *                    end
 *                end
 *            end
 *        endtask
 *    endclass
 *
 * 5. THIS PROJECT'S EXACT CHECKS (ASYNC FIFO)
 *    - Verification rule: Because a FIFO is First-In, First-Out, popping from the 
 *      front of `golden_queue` MUST always equal the `rd_data` from the chip.
 *    - Make sure to keep running totals of `match_count` and `error_count` so the 
 *      final summary can declare whether the chip passed or failed.
 * ============================================================================= */

`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

class fifo_scoreboard #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    mailbox #(trans_t)   mon2scb;
    bit [DATA_WIDTH-1:0] golden_queue[$];
    int                  match_count = 0;
    int                  error_count = 0;

    function new(mailbox #(trans_t) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run();
        trans_t tr;
        bit [DATA_WIDTH-1:0] expected;

        forever begin
            mon2scb.get(tr);

            if (tr.wr) begin
                golden_queue.push_back(tr.wr_data);
            end

            if (tr.rd) begin
                if (golden_queue.size() == 0) begin
                    $error("[SCB @ %0t ns] UNDERFLOW! Read occurred while reference model was empty.", $time);
                    error_count++;
                end else begin
                    expected = golden_queue.pop_front();
                    if (tr.rd_data !== expected) begin
                        $error("[SCB @ %0t ns] DATA MISMATCH! Received: 0x%02h, Expected: 0x%02h", 
                               $time, tr.rd_data, expected);
                        error_count++;
                    end else begin
                        match_count++;
                    end
                end
            end
        end
    endtask
endclass

`endif