`ifndef GENERATOR_SV
`define GENERATOR_SV

class fifo_generator #(parameter int DATA_WIDTH = 8);
    typedef fifo_transaction #(DATA_WIDTH) trans_t;

    mailbox #(trans_t) gen2drv_wr;
    mailbox #(trans_t) gen2drv_rd;
    int                num_transactions;
    event              done;

    function new(mailbox #(trans_t) gen2drv_wr, 
                 mailbox #(trans_t) gen2drv_rd, 
                 int num_transactions = 1000);
        this.gen2drv_wr       = gen2drv_wr;
        this.gen2drv_rd       = gen2drv_rd;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        for (int i = 0; i < num_transactions; i++) begin
            trans_t tr_wr = new();
            trans_t tr_rd = new();

            tr_wr.randomize_fields();
            tr_wr.wr = 1'b1; // Force valid write
            
            tr_rd.rd = 1'b1; // Pair with a valid read so every byte written is eventually popped

            gen2drv_wr.put(tr_wr);
            gen2drv_rd.put(tr_rd);
        end
        -> done;
    endtask
endclass

`endif