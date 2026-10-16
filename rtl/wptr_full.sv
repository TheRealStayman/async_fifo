module wptr_full #(
    parameter int ADDR_WIDTH = 4
)(
    input logic                     wr_clk,
    input logic                     wr_rst_n,
    input logic                     wr_en,
    input logic  [ADDR_WIDTH:0]     rq2_rptr,
    output logic [ADDR_WIDTH:0]     wr_ptr_gray,
    output logic [ADDR_WIDTH-1:0]   wr_addr,
    output logic                    wr_full
);
    logic [ADDR_WIDTH:0] wbin, wbin_next;
    logic [ADDR_WIDTH:0] wgray_next;
    logic full_val;

    assign wbin_next = wbin + (wr_en && !wr_full);      // Add 1 to wbin if possible
    assign wgray_next = wbin_next ^ (wbin_next >> 1);   // Convert wbin to graycode
    assign wr_addr = wbin[ADDR_WIDTH-1:0];              // Have the current write address be wbin

    // If the inverted first two MSBs of rq2_rptr and the rest of the bits (non-inverted) match wbin's graycode, the memory is full
    assign full_val = (wgray_next == {~rq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], rq2_rptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wbin        <= '0;
            wr_ptr_gray <= '0;
            wr_full     <= 1'b0;
        end else begin
            wbin        <= wbin_next;
            wr_ptr_gray <= wgray_next;
            wr_full     <= full_val;
        end
    end

endmodule