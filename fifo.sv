
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
            if (flush_en_i) begin
                write_ptr <= '0;
            end else begin
                case ({push_en_i, pop_en_i})
                    // 2'b00: no operation, keep the same pointer value
                    2'b01: begin
                        // pop operation, no change to write pointer
                        write_ptr <= write_ptr;
                    end
                    2'b10: begin
                        // push operation, increment write pointer
                        if (write_ptr == FIFO_SIZE - 1) begin
                            write_ptr <= '0; // wrap around if at the end
                        end else begin
                            write_ptr <= write_ptr + 1;
                        end
                    end
                    // 2'b11: direct forwarding, no change to write pointer
                    default: begin
                        // no operation, keep the same pointer value
                        write_ptr <= write_ptr;
                    end
                endcase
            end
        end
    end

    // read operation (pointer increment)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            read_ptr <= '0;
        end else begin
            if (flush_en_i) begin
                read_ptr <= '0;
            end else begin
                case ({push_en_i, pop_en_i})
                    // 2'b00: no operation, keep the same pointer value
                    2'b01: begin
                        // pop operation, increment read pointer
                        if (read_ptr == FIFO_SIZE - 1) begin
                            read_ptr <= '0; // wrap around if at the end
                        end else begin
                            read_ptr <= read_ptr + 1;
                        end
                    end
                    2'b10: begin
                        // push operation, no change to read pointer
                        read_ptr <= read_ptr;
                    end
                    // 2'b11: direct forwarding, no change to read pointer
                    default: begin
                        // no operation, keep the same pointer value
                        read_ptr <= read_ptr;
                    end
                endcase
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

    // flush, read, and write operations
    always @(*) begin
        data_d = '0; // default value for data_d
        for (int i = 0; i < FIFO_SIZE; i++) begin
            fifo_buffer_d[i] = fifo_buffer_q[i];
            valid_d[i] = valid_q[i];
        end
        if (flush_en_i) begin
            for (int i = 0; i < FIFO_SIZE; i++) begin
                fifo_buffer_d[i] = '0;
                valid_d[i] = '0;
            end
        end else begin
            case ({push_en_i, pop_en_i})
                // 2;b00: no operation, keep the same buffer values
                2'b01: begin
                    if (!empty_o) begin
                        // pop operation, read from the FIFO
                        data_d = {fifo_buffer_q[read_ptr][1], fifo_buffer_q[read_ptr][0]};
                        // mark the read entry as invalid
                        valid_d[read_ptr][1] = '0;
                        valid_d[read_ptr][0] = '0;
                    end
                end
                2'b10: begin
                    if (!full_o) begin
                        // push operation, write to the FIFO
                        fifo_buffer_d[write_ptr][1] = data_i[XLEN-1:16];
                        fifo_buffer_d[write_ptr][0] = data_i[15:0];
                        // mark the written entry as valid
                        valid_d[write_ptr][1] = 1'b1;
                        valid_d[write_ptr][0] = 1'b1;
                    end
                end
                2'b11: begin
                    data_d = data_i; // direct forwarding
                end
                default: begin
                    for (int i = 0; i < FIFO_SIZE; i++) begin
                        fifo_buffer_d[i] = fifo_buffer_q[i];
                        valid_d[i] = valid_q[i];
                    end
                end
            endcase
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


