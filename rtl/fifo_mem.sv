module fifo_mem #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    input logic                     wr_clk,
    input logic                     wr_en,
    input logic                     wr_full,
    input logic  [DATA_WIDTH-1:0]   wr_data,
    input logic  [ADDR_WIDTH-1:0]   wr_addr,
    input logic  [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data
);
    localparam int DEPTH = 1 << ADDR_WIDTH;

    // Memory Array Storage
    logic [DATA_WIDTH-1:0] ram[0:DEPTH-1];

    // Write Port (synchronous)
    always_ff @(posedge wr_clk) begin
        if (wr_en && !wr_full) begin
            ram[wr_addr] <= wr_data;
        end
    end

    // Read port (combinational)
    assign rd_data = ram[rd_addr];

endmodule