`ifndef TRANSACTION_SV
`define TRANSACTION_SV

class fifo_transaction #(parameter int DATA_WIDTH = 8);

    // Stimulus (Inputs to hardware) - Removed 'rand' to bypass license lock
    bit                  wr;
    bit                  rd;
    bit [DATA_WIDTH-1:0] wr_data;

    // Response & Status (Outputs observed from hardware)
    bit      [DATA_WIDTH-1:0] rd_data;
    bit                       full;
    bit                       empty;

    // Emulate constrained-random distribution using free standard built-ins
    function void randomize_fields();
        // 50% probability of write, 50% probability of read
        wr = $urandom_range(0, 1);
        rd = $urandom_range(0, 1);

        // Enforce the rule: at least one operation must be active
        if (!wr && !rd) begin
            if ($urandom_range(0, 1)) wr = 1'b1;
            else                      rd = 1'b1;
        end

        // Random data payload
        wr_data = $urandom;
    endfunction

    function void print(string tag = "TRANS");
        $display("[%0t ns] [%s] WR=%0b RD=%0b | WR_DATA=0x%02h | RD_DATA=0x%02h | FULL=%0b EMPTY=%0b",
                 $time, tag, wr, rd, wr_data, rd_data, full, empty);
    endfunction

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