
module fifo #(
    parameter XLEN = 32,
    parameter FIFO_SIZE = 4
) (
    input                           clk_i,
    input                           rst_ni,
    input                           flush_en_i,
    input                           push_en_i,
    input           [XLEN-1:0]      data_i,
    input                           pop_en_i,
    output  logic   [XLEN-1:0]      data_o,
    // FIFO status signals
    output  logic                   full_o,
    output  logic                   empty_o
);

    // data structure to hold fetched instructions (16 x 2) and if it is valid
    logic [1:0][15:0] fifo_buffer_q[FIFO_SIZE];
    logic [1:0] valid_q[FIFO_SIZE];

    // data structure to hold fetched instructions (16 x 2) and if it is valid (for internal use)
    logic [1:0][15:0] fifo_buffer_d[FIFO_SIZE];
    logic [1:0] valid_d[FIFO_SIZE];

    logic [XLEN-1:0] data_q;
    logic [XLEN-1:0] data_d;

    // write pointer
    logic [$clog2(FIFO_SIZE)-1:0] write_ptr;
    // read pointer
    logic [$clog2(FIFO_SIZE)-1:0] read_ptr;
    

    // write operation (pointer increment)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            write_ptr <= '0;
        end else begin
            if (push_en_i) begin
                if (write_ptr == FIFO_SIZE - 1) begin
                    write_ptr <= '0; // wrap around if at the end
                end else begin
                    write_ptr <= write_ptr + 1;
                end
            end else begin
                write_ptr <= write_ptr;
            end
        end
    end

    // read operation (pointer increment)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            read_ptr <= '0;
        end else begin
            if (pop_en_i) begin
                if (read_ptr == FIFO_SIZE - 1) begin
                    read_ptr <= '0; // wrap around if at the end
                end else begin
                    // only increment if there is valid data to read
                    read_ptr <= read_ptr + 1;
                end
            end else begin
                read_ptr <= read_ptr;
            end
        end
    end


    // FIFO Buffer
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            for (int i = 0; i < FIFO_SIZE; i++) begin
                fifo_buffer_q[i] <= '0;
                valid_q[i] <= '0;
            end
        end else begin
            if (flush_en_i) begin
                for (int i = 0; i < FIFO_SIZE; i++) begin
                    fifo_buffer_q[i] <= '0;
                    valid_q[i] <= '0;
                end
            end else begin
                for (int i = 0; i < FIFO_SIZE; i++) begin
                    fifo_buffer_q[i] <= fifo_buffer_d[i];
                    valid_q[i] <= valid_d[i];
                end
            end
        end
    end

    // write fetched instruction into the buffer
    always @(*) begin
        for (int i = 0; i < FIFO_SIZE; i++) begin
            fifo_buffer_d[i] = fifo_buffer_q[i]; // default to hold previous value
            valid_d[i] = valid_q[i]; // default to hold previous validity
        end
        if (push_en_i) begin
            fifo_buffer_d[write_ptr][0] = data_i[(XLEN/2)-1:0];
            fifo_buffer_d[write_ptr][1] = data_i[XLEN-1:(XLEN/2)];
            valid_d[write_ptr] = 2'b11; // mark both halves as valid
        end else begin
            for (int i = 0; i < FIFO_SIZE; i++) begin
                fifo_buffer_d[i] = fifo_buffer_q[i]; // default to hold previous value
                valid_d[i] = valid_q[i]; // default to hold previous validity
            end
        end
    end

    // read instruction from the buffer
    always @(*) begin
        data_d = data_q; // default to hold previous value
        for (int i = 0; i < FIFO_SIZE; i++) begin
            valid_d[i] = valid_q[i]; // default to hold previous validity
        end
        if (pop_en_i && (valid_q[read_ptr] != 2'b00)) begin
            data_d = {fifo_buffer_q[read_ptr][1], fifo_buffer_q[read_ptr][0]};
            valid_d[read_ptr] = 2'b00; // mark as invalid after reading
        end else begin
            data_d = data_q; 
        end
    end

    // data_q register
    // update data_q with the read value
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            data_q <= '0;
        end else begin
            data_q <= data_d;
        end
    end

    assign data_o = data_q;

    // FIFO full and empty status
    assign full_o = (valid_q[write_ptr] != 2'b00); // FIFO is full if the write pointer points to a valid entry
    assign empty_o = (valid_q[read_ptr] == 2'b00); // FIFO is empty if the read pointer points to an invalid entry


endmodule


