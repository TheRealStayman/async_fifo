module sync_2ff #(
    parameter int WIDTH = 5
)(
    input logic                 clk,
    input logic                 rst_n,
    input logic  [WIDTH-1:0]    din,
    output logic [WIDTH-1:0]    dout
);

    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] stage1, stage2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= '0;
            stage2 <= '0;
        end else begin
            stage1 <= din;
            stage2 <= stage1;
        end
    end

    assign dout = stage2;

endmodule