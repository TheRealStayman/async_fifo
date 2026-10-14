module async_fifo_top #(
    parameter int ADDR_WIDTH = 4, // Keep small to avoid turning fifo_mem into bram.
    parameter int DATA_WIDTH = 8
)(
    // Write Domain Interface
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  wr_full,

    // Read Domain Interface
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_empty
);

    // Local Nets (it's all about the nets)
    logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    logic [ADDR_WIDTH:0]   wgray, rgray;
    logic [ADDR_WIDTH:0]   rq2_rptr, wq2_wptr;

    // Dual-Port Memory Storage
    fifo_mem #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_fifo_mem (
        .wr_clk     (wr_clk),
        .wr_en      (wr_en),
        .wr_full    (wr_full),
        .wr_data    (wr_data),
        .wr_addr    (wr_addr),
        .rd_addr    (rd_addr),
        .rd_data    (rd_data)
    );

    // Write Domain Pointer & Full Flag Generation
    wptr_full #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_wptr_full (
        .wr_clk      (wr_clk),
        .wr_rst_n    (wr_rst_n),
        .wr_en       (wr_en),
        .rq2_rptr    (rq2_rptr),
        .wr_addr     (wr_addr),
        .wr_ptr_gray (wgray),
        .wr_full     (wr_full)
    );

    // Read Domain Pointer & Empty Flag Generation
    rptr_empty #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_rptr_empty (
        .rd_clk      (rd_clk),
        .rd_rst_n    (rd_rst_n),
        .rd_en       (rd_en),
        .wq2_wptr    (wq2_wptr),
        .rd_addr     (rd_addr),
        .rd_ptr_gray (rgray),
        .rd_empty    (rd_empty)
    );

    // Synchronize Write Pointer to Read Domain (Clocked by rd_clk)
    sync_2ff #(
        .WIDTH (ADDR_WIDTH + 1)
    ) u_sync_w2r (
        .clk   (rd_clk),
        .rst_n (rd_rst_n),
        .din   (wgray),
        .dout  (wq2_wptr)
    );

    // Synchronize Read Pointer to Write Domain (Clocked by wr_clk)
    sync_2ff #(
        .WIDTH (ADDR_WIDTH + 1)
    ) u_sync_r2w (
        .clk   (wr_clk),
        .rst_n (wr_rst_n),
        .din   (rgray),
        .dout  (rq2_rptr)
    );

endmodule