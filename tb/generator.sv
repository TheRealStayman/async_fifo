/* =============================================================================
 * FILE: generator.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    The generator is an automated scenario creator. It sits at a desk, fills out 
 *    hundreds or thousands of digital transaction note cards with random 
 *    instructions (following your constraint rules), and drops them into an 
 *    outbox (Mailbox) for the driver to pick up.
 *    The generator knows NOTHING about physical wires, voltage, or clock ticks. 
 *    It only knows how to create cards, randomize them, and put them in the box.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Safe communication tube (Mailbox): A thread-safe software buffer where one 
 *      process drops off an item (`put`) and another picks it up (`get`). If the 
 *      box is empty, the receiver pauses and waits automatically.
 *    - Signal flag / Walkie-talkie beep (Event / `event`): A simple signal used 
 *      to notify another piece of code that something finished (`-> done`).
 *    - Time-consuming action (Task): A subroutine in SystemVerilog that takes time 
 *      on the clock (unlike a `function`, which must execute in zero time).
 *    - Crash the program (Fatal error / `$fatal`): A command that immediately 
 *      halts simulation and prints a failure message if something is broken.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare the class `fifo_generator` with the `DATA_WIDTH` parameter.
 *    Step 2: Declare three member variables:
 *            - A `mailbox` to hold the transactions.
 *            - An integer `num_transactions` (how many cards to generate).
 *            - An `event done` (a flag to notify the testbench when finished).
 *    Step 3: Write a constructor function (`new`) that accepts the shared mailbox 
 *            handle and an optional transaction count (e.g., default 1000).
 *    Step 4: Write a `task run()`:
 *            - Create a loop that runs `num_transactions` times.
 *            - Inside the loop, allocate a brand new transaction: `tr = new()`.
 *            - Call `tr.randomize()`. If it returns 0 (failed), call `$fatal`.
 *            - Drop the transaction into the mailbox: `gen2drv.put(tr)`.
 *            - After the loop completes, trigger the finish flag: `-> done`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    class my_generator;
 *        mailbox #(my_trans) box;
 *        int count;
 *        event done;
 *
 *        function new(mailbox #(my_trans) box, int count = 500);
 *            this.box   = box;
 *            this.count = count;
 *        endfunction
 *
 *        task run();
 *            for (int i = 0; i < count; i++) begin
 *                my_trans tr = new();
 *                if (!tr.randomize()) begin
 *                    $fatal(1, "Randomization broken!");
 *                end
 *                box.put(tr); // Put card into outbox
 *            end
 *            -> done; // Ring the completion bell
 *        endtask
 *    endclass
 *
 * 5. THIS PROJECT'S EXACT IMPLEMENTATION (ASYNC FIFO)
 *    - Mailbox type: `mailbox #(fifo_transaction#(DATA_WIDTH)) gen2drv`
 *    - Transaction count: Set the default between 1,000 and 2,000 operations so 
 *      the FIFO experiences long write bursts and long read bursts.
 * ============================================================================= */

`ifndef GENERATOR_SV
`define GENERATOR_SV

class fifo_generator #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    mailbox #(trans_t) gen2drv_wr;
    mailbox #(trans_t) gen2drv_rd;
    int                num_transactions;
    event              done;

    function new(mailbox #(trans_t) gen2drv_wr, 
                 mailbox #(trans_t) gen2drv_rd, 
                 int num_transactions = 1000);
        this.gen2drv_wr       = gen2drv_wr;
        this.gen2drv_rd       = gen2drv_rd;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        for (int i = 0; i < num_transactions; i++) begin
            trans_t tr_wr = new();
            trans_t tr_rd = new();

            tr_wr.randomize_fields();
            tr_wr.wr = 1'b1; // Force valid write
            
            tr_rd.rd = 1'b1; // Pair with a valid read so every byte written is eventually popped

            gen2drv_wr.put(tr_wr);
            gen2drv_rd.put(tr_rd);
        end
        -> done;
    endtask
endclass

`endif