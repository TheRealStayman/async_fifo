module rptr_empty #(
    parameter int ADDR_WIDTH = 4
)(
    input logic                     rd_clk,
    input logic                     rd_rst_n,
    input logic                     rd_en,
    input logic  [ADDR_WIDTH:0]     wq2_wptr,
    output logic [ADDR_WIDTH:0]     rd_ptr_gray,
    output logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic                    rd_empty
);
    logic [ADDR_WIDTH:0] rbin, rbin_next;
    logic [ADDR_WIDTH:0] rgray_next;
    logic empty_val;

    assign rbin_next = rbin + (rd_en && !rd_empty);      // Add 1 to rbin if possible
    assign rgray_next = rbin_next ^ (rbin_next >> 1);   // Convert rbin to graycode
    assign rd_addr = rbin[ADDR_WIDTH-1:0];              // Have the current read address be rbin

    // If wq2_wptr matches wbin's graycode, the memory is empty
    assign empty_val = (rgray_next == wq2_wptr);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rbin        <= '0;
            rd_ptr_gray <= '0;
            rd_empty    <= 1'b1;
        end else begin
            rbin        <= rbin_next;
            rd_ptr_gray <= rgray_next;
            rd_empty    <= empty_val;
        end
    end

endmodule