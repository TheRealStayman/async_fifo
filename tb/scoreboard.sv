`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

class fifo_scoreboard #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    mailbox #(trans_t)   mon2scb;
    bit [DATA_WIDTH-1:0] golden_queue[$];
    int                  match_count = 0;
    int                  error_count = 0;

    function new(mailbox #(trans_t) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run();
        trans_t tr;
        bit [DATA_WIDTH-1:0] expected;

        forever begin
            mon2scb.get(tr);

            if (tr.wr) begin
                golden_queue.push_back(tr.wr_data);
            end

            if (tr.rd) begin
                if (golden_queue.size() == 0) begin
                    $error("[SCB @ %0t ns] UNDERFLOW! Read occurred while reference model was empty.", $time);
                    error_count++;
                end else begin
                    expected = golden_queue.pop_front();
                    if (tr.rd_data !== expected) begin
                        $error("[SCB @ %0t ns] DATA MISMATCH! Received: 0x%02h, Expected: 0x%02h", 
                               $time, tr.rd_data, expected);
                        error_count++;
                    end else begin
                        match_count++;
                    end
                end
            end
        end
    endtask
endclass

`endif