/* =============================================================================
 * FILE: transaction.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    Instead of thinking about individual electrical wires toggling on every 
 *    clock tick, think of a transaction like a digital note card (discrete data 
 *    packet / abstract representation of pin-level activity). 
 *    
 *    If you want to send mail, you don't worry about every footstep the mailman 
 *    takes; you write a letter with an action ("deliver this") and cargo ("the 
 *    contents"). That letter is a transaction. It bundles:
 *    - The action you want to take (control fields, like "write" or "read").
 *    - The cargo you want to move (input payload / payload byte / data word).
 *    - The results that come back from the chip (output response / status fields).
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Blueprint for an object (Class): A software container that bundles variables 
 *      and functions together into one neat package (Encapsulation).
 *    - Variables inside the blueprint (Member variables / Transaction members): 
 *      The specific pieces of data written on that digital note card.
 *    - Cargo (Input payload / Payload byte / Data word): The actual numeric data 
 *      you want to store or transfer (e.g., an 8-bit number like 8'hA5).
 *    - Control switches (Control fields): The flags telling the hardware what 
 *      action to take (e.g., `wr` for write, `rd` for read).
 *    - "Please write this" (Write enable request): Turning on the write wire for 
 *      one cycle to ask the chip to accept your data.
 *    - Chip's answer (Output response / Status fields): What the hardware answers 
 *      back (e.g., `rd_data`, `full`, `empty`). These are created by the physical 
 *      chip logic (driven by the hardware), NOT by our test software.
 *    - Spied on / Checked (Observed): Looking at a wire's value from the outside 
 *      without interfering with it.
 *    - Smart randomizer (Constraint solver): The simulator's math engine that picks 
 *      random numbers for you while following your rules.
 *    - Rule book for random numbers (Constraint blocks): Code blocks that set legal 
 *      boundaries (restrict random values / valid protocol bounds) so the randomizer 
 *      doesn't pick nonsense.
 *    - Loaded dice (Weighted distribution): Forcing certain random choices to happen 
 *      more often than others (e.g., 70% chance of rolling a 1, 30% chance of 0).
 *    - Stress-testing rare bugs (Bias generation toward corner cases): Intentionally 
 *      making rare, difficult conditions happen frequently (like filling the buffer 
 *      completely full or reading while empty) to catch edge-case bugs.
 *    - Range checker (Set-membership operator / `inside`): A shortcut syntax that 
 *      checks if a number lives within a specific range, like `x inside {[1:10]}`.
 *    - No wasted cycles (Activity constraint against empty idle transactions): A rule 
 *      that forces either a write OR a read to happen so simulation doesn't waste 
 *      time doing nothing.
 *    - "Myself" (Implicit handle / `this`): A keyword referring to the specific 
 *      object instance currently running the code.
 *    - Cloning a card (Deep copy vs. Shallow copy):
 *      * Shallow copy: Copying just the pointer/address (like sharing a link to 
 *        the same Google Doc). If you change one, both change!
 *      * Deep copy: Making a 100% independent paper duplicate of the document.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare the class. Add a parameter for data width (Parameterization) 
 *            so the bit-width can be easily changed later without rewriting code.
 *    Step 2: Declare your inputs (`wr`, `rd`, `wr_data`) using the `rand` keyword 
 *            so the constraint solver knows to pick random values for them.
 *    Step 3: Declare your outputs (`rd_data`, `full`, `empty`) as standard `bit` 
 *            types WITHOUT `rand` (since the chip generates them).
 *    Step 4: Create a `constraint` block setting the odds (Weighted distribution / 
 *            Operation distribution) of writes vs. reads.
 *    Step 5: Create a `constraint` block ensuring at least one operation happens 
 *            (`wr || rd == 1`) so you don't generate blank, useless cycles.
 *    Step 6: Write a `print()` function using `$display` so you can read the 
 *            card's contents in the simulation log.
 *    Step 7: Write a `copy()` function that creates a new object (`new()`) and 
 *            copies every variable over one by one (Deep copy).
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    // Parameterized class blueprint:
 *    class my_trans #(parameter int WIDTH = 8);
 *
 *        // Random inputs:
 *        rand bit             action_flag;
 *        rand bit [WIDTH-1:0] cargo_data;
 *
 *        // Non-random outputs:
 *        bit [WIDTH-1:0]      result_data;
 *        bit                  alarm_flag;
 *
 *        // Constraint with weighted odds:
 *        constraint odds_c {
 *            action_flag dist { 1 := 70, 0 := 30 }; // 70% chance 1, 30% chance 0
 *        }
 *
 *        // Constraint forcing at least one action:
 *        constraint must_do_something_c {
 *            cargo_data != 0;
 *        }
 *
 *        // Deep copy function:
 *        function my_trans#(WIDTH) copy();
 *            my_trans#(WIDTH) clone = new();
 *            clone.action_flag = this.action_flag;
 *            clone.cargo_data  = this.cargo_data;
 *            return clone;
 *        endfunction
 *
 *    endclass
 *
 * 5. THIS PROJECT'S EXACT VARIABLES (ASYNC FIFO)
 *    - Parameters: `DATA_WIDTH = 8`
 *    - Random Inputs:
 *      * `rand bit wr;`
 *      * `rand bit rd;`
 *      * `rand bit [DATA_WIDTH-1:0] wr_data;`
 *    - Non-Random Outputs:
 *      * `bit [DATA_WIDTH-1:0] rd_data;`
 *      * `bit full;`
 *      * `bit empty;`
 *    - Constraints:
 *      * `op_dist_c`: Give `wr` and `rd` a 50/50 chance each of being 1 or 0.
 *      * `active_c`: Enforce `(wr || rd) == 1'b1;`
 * ============================================================================= */

 `ifndef TRANSACTION_SV
`define TRANSACTION_SV

class fifo_transaction #(parameter int DATA_WIDTH = 8);

    // Stimulus (Inputs to the hardware)
    rand bit                  wr;
    rand bit                  rd;
    rand bit [DATA_WIDTH-1:0] wr_data;

    // Response & Status (Outputs observed from hardware)
    bit      [DATA_WIDTH-1:0] rd_data;
    bit                       full;
    bit                       empty;

    // Probability weighting: 50% chance of write, 50% chance of read
    constraint op_dist_c {
        wr dist { 1 := 50, 0 := 50 };
        rd dist { 1 := 50, 0 := 50 };
    }

    // Force at least one operation so we do not generate idle cycles
    constraint at_least_one_op_c {
        (wr || rd) == 1'b1;
    }

    function void print(string tag = "TRANS");
        $display("[%0t ns] [%s] WR=%0b RD=%0b | WR_DATA=0x%02h | RD_DATA=0x%02h | FULL=%0b EMPTY=%0b",
                 $time, tag, wr, rd, wr_data, rd_data, full, empty);
    endfunction

    // Deep copy creates a fresh object instead of duplicating a pointer handle
    function fifo_transaction#(DATA_WIDTH) copy();
        fifo_transaction#(DATA_WIDTH) clone;
        clone         = new();
        clone.wr      = this.wr;
        clone.rd      = this.rd;
        clone.wr_data = this.wr_data;
        clone.rd_data = this.rd_data;
        clone.full    = this.full;
        clone.empty   = this.empty;
        return clone;
    endfunction

endclass

`endif