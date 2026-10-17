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