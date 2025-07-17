`timescale 1ns/1ps

module tb_fifo;

// Parameters
localparam CLK_PERIOD = 10; // Clock period in ns
localparam XLEN = 32;
localparam FIFO_SIZE = 4;

// Test control variables
integer test_count = 0;
integer error_count = 0;
logic [XLEN-1:0] test_data_queue[$];
logic [XLEN-1:0] expected_data;

// Inputs
logic clk_i;
logic rst_ni;
logic flush_en_i;
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
    .flush_en_i(flush_en_i),
    .push_en_i(push_en_i),
    .pop_en_i(pop_en_i),
    .data_i(data_i),
    .data_o(data_o),
    .full_o(full_o),
    .empty_o(empty_o)
);

// Clock generation
always #(CLK_PERIOD / 2) clk_i = ~clk_i;

// Task to initialize signals
task initialize();
    clk_i = 0;
    rst_ni = 0;
    flush_en_i = 0;
    push_en_i = 0;
    pop_en_i = 0;
    data_i = 0;
    test_data_queue.delete();
endtask

// Task to apply reset
task apply_reset();
    $display("=== Applying Reset ===");
    @(negedge clk_i);
    rst_ni = 0;
    @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);
endtask

// Task to push data
task push_data(input logic [XLEN-1:0] data);
    @(negedge clk_i);
    push_en_i = 1;
    data_i = data;
    test_data_queue.push_back(data);
    @(negedge clk_i);
    push_en_i = 0;
    $display("Pushed data: 0x%h, Full: %b, Empty: %b", data, full_o, empty_o);
endtask

// Task to pop data
task pop_data();
    @(negedge clk_i);
    pop_en_i = 1;
    @(negedge clk_i);
    pop_en_i = 0;
    
    if (test_data_queue.size() > 0) begin
        expected_data = test_data_queue.pop_front();
        if (data_o !== expected_data) begin
            $display("ERROR: Expected 0x%h, got 0x%h", expected_data, data_o);
            error_count++;
        end else begin
            $display("Popped data: 0x%h, Full: %b, Empty: %b", data_o, full_o, empty_o);
        end
    end else begin
        $display("ERROR: Attempted to pop from empty queue");
        error_count++;
    end
endtask

// Task to check flags
task check_flags();
    if (empty_o && test_data_queue.size() != 0) begin
        $display("ERROR: Empty flag incorrect - Queue size: %d", test_data_queue.size());
        error_count++;
    end
    if (full_o && test_data_queue.size() != FIFO_SIZE) begin
        $display("ERROR: Full flag incorrect - Queue size: %d", test_data_queue.size());
        error_count++;
    end
endtask

// Task to flush FIFO
task flush_fifo();
    $display("=== Flushing FIFO ===");
    @(negedge clk_i);
    flush_en_i = 1;
    @(negedge clk_i);
    flush_en_i = 0;
    test_data_queue.delete();
    $display("FIFO flushed, Empty: %b, Full: %b", empty_o, full_o);
endtask

// Test case 1: Basic push/pop operations
task test_basic_operations();
    $display("\n=== TEST 1: Basic Push/Pop Operations ===");
    test_count++;
    
    apply_reset();
    
    // Check initial state
    if (!empty_o || full_o) begin
        $display("ERROR: Initial state incorrect - Empty: %b, Full: %b", empty_o, full_o);
        error_count++;
    end
    
    // Push some data
    push_data(32'hDEADBEEF);
    push_data(32'hCAFEBABE);
    push_data(32'h12345678);
    
    // Pop data
    pop_data();
    pop_data();
    pop_data();
    
    check_flags();
endtask

// Test case 2: Fill and empty FIFO
task test_fill_empty();
    $display("\n=== TEST 2: Fill and Empty FIFO ===");
    test_count++;
    
    apply_reset();
    
    // Fill the FIFO completely
    for (int i = 0; i < FIFO_SIZE; i++) begin
        push_data(32'hA0000000 + i);
    end
    
    // Check if full
    if (!full_o) begin
        $display("ERROR: FIFO should be full");
        error_count++;
    end
    
    // Try to push when full (should be ignored)
    $display("Attempting to push when full...");
    @(negedge clk_i);
    push_en_i = 1;
    data_i = 32'hFFFFFFFF;
    @(negedge clk_i);
    push_en_i = 0;
    
    // Empty the FIFO completely
    for (int i = 0; i < FIFO_SIZE; i++) begin
        pop_data();
    end
    
    // Check if empty
    if (!empty_o) begin
        $display("ERROR: FIFO should be empty");
        error_count++;
    end
    
    // Try to pop when empty
    $display("Attempting to pop when empty...");
    @(negedge clk_i);
    pop_en_i = 1;
    @(posedge clk_i);
    pop_en_i = 0;
    
    check_flags();
endtask

// Test case 3: Simultaneous push and pop
task test_simultaneous_push_pop();
    $display("\n=== TEST 3: Simultaneous Push and Pop ===");
    test_count++;
    
    apply_reset();
    
    // Fill half the FIFO
    push_data(32'hAAAAAAAA);
    push_data(32'hBBBBBBBB);
    
    // Simultaneous push and pop
    for (int i = 0; i < 5; i++) begin
        @(negedge clk_i);
        push_en_i = 1;
        pop_en_i = 1;
        data_i = 32'hC0000000 + i;
        
        // Update our queue model
        if (test_data_queue.size() > 0) begin
            expected_data = test_data_queue.pop_front();
        end
        test_data_queue.push_back(data_i);
        
        @(posedge clk_i);
        push_en_i = 0;
        pop_en_i = 0;
        
        $display("Simultaneous: Pushed 0x%h, Popped 0x%h", data_i, data_o);
    end
    
    check_flags();
endtask

// Test case 4: Flush operation
task test_flush();
    $display("\n=== TEST 4: Flush Operation ===");
    test_count++;
    
    apply_reset();
    
    // Fill some data
    push_data(32'h11111111);
    push_data(32'h22222222);
    push_data(32'h33333333);
    
    // Flush
    flush_fifo();
    
    // Check if empty after flush
    if (!empty_o || full_o) begin
        $display("ERROR: FIFO should be empty after flush");
        error_count++;
    end
    
    // Add new data after flush
    push_data(32'h44444444);
    pop_data();
    
    check_flags();
endtask

// Test case 5: Reset during operation
task test_reset_during_operation();
    $display("\n=== TEST 5: Reset During Operation ===");
    test_count++;
    
    apply_reset();
    
    // Fill some data
    push_data(32'hFEDCBA98);
    push_data(32'h76543210);
    
    // Reset during operation
    @(negedge clk_i);
    rst_ni = 0;
    push_en_i = 1;
    data_i = 32'h99999999;
    @(posedge clk_i);
    push_en_i = 0;
    
    // Release reset
    @(negedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);
    
    // Clear our queue model
    test_data_queue.delete();
    
    // Check if empty after reset
    if (!empty_o || full_o) begin
        $display("ERROR: FIFO should be empty after reset");
        error_count++;
    end
    
    check_flags();
endtask

// Test case 6: Random operations
task test_random_operations();
    $display("\n=== TEST 6: Random Operations ===");
    test_count++;
    
    apply_reset();
    
    // Perform random operations
    for (int i = 0; i < 20; i++) begin
        int operation = $random % 3;
        
        case (operation)
            0: begin // Push
                if (test_data_queue.size() < FIFO_SIZE) begin
                    logic [XLEN-1:0] random_data = $random;
                    push_data(random_data);
                end
            end
            1: begin // Pop
                if (test_data_queue.size() > 0) begin
                    pop_data();
                end
            end
            2: begin // Flush
                flush_fifo();
            end
        endcase
        
        check_flags();
        
        // Wait a clock cycle
        @(posedge clk_i);
    end
endtask

// Test case 7: Edge cases
task test_edge_cases();
    $display("\n=== TEST 7: Edge Cases ===");
    test_count++;
    
    apply_reset();
    
    // Test with all zeros
    push_data(32'h00000000);
    pop_data();
    
    // Test with all ones
    push_data(32'hFFFFFFFF);
    pop_data();
    
    // Test alternating patterns
    push_data(32'hAAAAAAAA);
    push_data(32'h55555555);
    pop_data();
    pop_data();
    
    // Test boundary values
    push_data(32'h80000000);
    push_data(32'h7FFFFFFF);
    pop_data();
    pop_data();
    
    check_flags();
endtask

// Main test sequence
initial begin
    // VCD file generation
    $dumpfile("tb_fifo.vcd");
    $dumpvars(0, tb_fifo);
    
    initialize();
    
    $display("Starting FIFO Testbench...");
    $display("FIFO_SIZE: %d, XLEN: %d", FIFO_SIZE, XLEN);
    
    // Run all test cases
    test_basic_operations();
    test_fill_empty();
    test_simultaneous_push_pop();
    test_flush();
    test_reset_during_operation();
    test_random_operations();
    test_edge_cases();
    
    // Wait for a few clock cycles
    repeat (10) @(posedge clk_i);
    
    // Final report
    $display("\n=== TEST SUMMARY ===");
    $display("Total tests run: %d", test_count);
    $display("Total errors: %d", error_count);
    
    if (error_count == 0) begin
        $display("*** ALL TESTS PASSED! ***");
    end else begin
        $display("*** %d TESTS FAILED! ***", error_count);
    end
    
    $finish;
end

endmodule