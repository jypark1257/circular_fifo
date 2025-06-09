`timescale 1ns/1ps

module tb_fifo;

    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in ns
    localparam XLEN = 32;
    localparam FIFO_SIZE = 4;

    // Inputs
    logic clk_i;
    logic rst_ni;
    logic push_en_i;
    logic pop_en_i;
    logic [XLEN-1:0] data_i;

    // Outputs
    logic [XLEN-1:0] data_o;
    logic full_o;
    logic empty_o;

    // Instantiate the FIFO module
    fifo #(
        .XLEN(XLEN),
        .FIFO_SIZE(FIFO_SIZE)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .push_en_i(push_en_i),
        .pop_en_i(pop_en_i),
        .data_i(data_i),
        .data_o(data_o),
        .full_o(full_o), // Not used in this testbench
        .empty_o(empty_o) // Not used in this testbench
    );


    // Clock generation
    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    initial begin
        // vcd file generation
        $dumpfile("tb_fifo.vcd");
        $dumpvars(0, tb_fifo);
        clk_i = 0;
        rst_ni = 0;
        push_en_i = 0;
        pop_en_i = 0;
        data_i = 0;
        // Reset the FIFO
        @(negedge clk_i);
        rst_ni = 1;
        @(posedge clk_i);
        // Push data into the FIFO
        @(negedge clk_i);
        push_en_i = 1;
        data_i = $random;
        @(posedge clk_i);
        // Push another data
        @(negedge clk_i);
        push_en_i = 1;
        data_i = $random;
        @(posedge clk_i);
        // Push another data
        @(negedge clk_i);
        push_en_i = 1;
        data_i = $random;
        @(posedge clk_i);
        // Push another data
        @(negedge clk_i);
        push_en_i = 1;
        data_i = $random;
        @(posedge clk_i);
        @(negedge clk_i);
        // Disable push
        push_en_i = 0;
        // Pop data from the FIFO
        @(negedge clk_i);
        pop_en_i = 1;
        @(posedge clk_i);
        // Check the output data
        @(negedge clk_i);
        if (data_o !== dut.fifo_buffer_q[0]) begin
            $display("Error: Expected %h, got %h", dut.fifo_buffer_q[0], data_o);
        end else begin
            $display("Data popped: %h", data_o);
        end
        // Pop another data
        pop_en_i = 1;
        @(posedge clk_i);
        // Check the output data
        @(negedge clk_i);
        if (data_o !== dut.fifo_buffer_q[1]) begin
            $display("Error: Expected %h, got %h", dut.fifo_buffer_q[1], data_o);
        end else begin
            $display("Data popped: %h", data_o);
        end
        // Pop another data
        pop_en_i = 1;
        @(posedge clk_i);
        // Check the output data
        @(negedge clk_i);
        if (data_o !== dut.fifo_buffer_q[2]) begin
            $display("Error: Expected %h, got %h", dut.fifo_buffer_q[2], data_o);
        end else begin
            $display("Data popped: %h", data_o);
        end         
        // Pop another data
        pop_en_i = 1;
        @(posedge clk_i);
        // Check the output data
        @(negedge clk_i);
        if (data_o !== dut.fifo_buffer_q[3]) begin
            $display("Error: Expected %h, got %h", dut.fifo_buffer_q[3], data_o);
        end else begin
            $display("Data popped: %h", data_o);
        end
        // Disable pop
        pop_en_i = 0;

        repeat (5) @(posedge clk_i); // Wait for a few clock cycles
        // End simulation
        $finish;
    end



endmodule