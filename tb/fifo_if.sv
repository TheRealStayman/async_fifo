/* =============================================================================
 * FILE: fifo_if.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    An interface is like a wiring harness or cable bundle. Instead of running 
 *    10 separate loose wires all across your living room, you pack them into a 
 *    single HDMI cable. Any module that needs to talk to the chip just plugs in 
 *    this one cable bundle.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Wire bundle (Interface): A SystemVerilog construct grouping physical nets 
 *      together so modules and classes can connect to them as a single port.
 *    - Universal digital wire (Logic / `logic`): The modern SystemVerilog signal 
 *      type that replaces the old confusion between `reg` and `wire`.
 *    - Bridge between software and hardware (Virtual Interface): Classes are 
 *      dynamic software that live in PC RAM; the DUT is simulated physical silicon. 
 *      A `virtual interface` is the pointer/handle that allows software classes 
 *      to reach into the simulated hardware and wiggle pins.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Declare `interface fifo_if #(parameter int DATA_WIDTH = 8) (...)`.
 *    Step 2: In the interface port header, accept the clocks and resets:
 *            `input logic wr_clk, rd_clk, wr_rst_n, rd_rst_n`.
 *    Step 3: Inside the interface body, declare all the data and flow-control 
 *            wires using `logic`:
 *            - Write side: `wr_en`, `wr_data`, `wr_full`.
 *            - Read side: `rd_en`, `rd_data`, `rd_empty`.
 *
 * 4. SYNTAX PATTERNS (COPY & ADAPT)
 *    interface my_cable #(parameter int WIDTH = 8) (
 *        input logic clk,
 *        input logic rst_n
 *    );
 *        logic             enable;
 *        logic [WIDTH-1:0] data;
 *        logic             alarm;
 *    endinterface
 *
 * 5. THIS PROJECT'S EXACT SIGNALS (ASYNC FIFO)
 *    - Header inputs: `wr_clk`, `rd_clk`, `wr_rst_n`, `rd_rst_n`
 *    - Write bundle signals:
 *      * `logic wr_en;`
 *      * `logic [DATA_WIDTH-1:0] wr_data;`
 *      * `logic wr_full;`
 *    - Read bundle signals:
 *      * `logic rd_en;`
 *      * `logic [DATA_WIDTH-1:0] rd_data;`
 *      * `logic rd_empty;`
 * ============================================================================= */

`ifndef FIFO_IF_SV
`define FIFO_IF_SV

interface fifo_if #(parameter int DATA_WIDTH = 8) (
    input logic wr_clk,
    input logic rd_clk,
    input logic wr_rst_n,
    input logic rd_rst_n
);

    // Write Domain Nets
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  wr_full;

    // Read Domain Nets
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rd_empty;

    // =========================================================================
    // PIN-LEVEL PROTOCOL ASSERTIONS (Always Active)
    // =========================================================================

    // 1. Reset Check: When wr_rst_n is low, wr_full must be 0
    always @(posedge wr_clk) begin
        if (!wr_rst_n) begin
            assert (wr_full === 1'b0) 
                else $error("[%0t ns] [ASSERT FAIL] wr_full is not 0 during reset!", $time);
        end
    end

    // 2. Reset Check: When rd_rst_n is low, rd_empty must be 1
    always @(posedge rd_clk) begin
        if (!rd_rst_n) begin
            assert (rd_empty === 1'b1) 
                else $error("[%0t ns] [ASSERT FAIL] rd_empty is not 1 during reset!", $time);
        end
    end

    // 3. Overflow Protection Check: Driver/Master must not write when full
    always @(posedge wr_clk) begin
        if (wr_rst_n && wr_full && wr_en) begin
            $error("[%0t ns] [PROTOCOL VIOLATION] Write attempted while FIFO is FULL!", $time);
        end
    end

    // 4. Underflow Protection Check: Driver/Master must not read when empty
    always @(posedge rd_clk) begin
        if (rd_rst_n && rd_empty && rd_en) begin
            $error("[%0t ns] [PROTOCOL VIOLATION] Read attempted while FIFO is EMPTY!", $time);
        end
    end

endinterface

`endif