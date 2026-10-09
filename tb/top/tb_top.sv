`timescale 1ns/1ps
module tb_top;
    import uvm_pkg::*;
    import max5_pkg::*;

    // 100 MHz clock
    logic clk = 0;
    always #5 clk = ~clk;

    max5_if #(.W(max5_pkg::W)) vif (clk);

    // rst_n is driven by the driver (RESET items)
    max_of_5 #(.W(max5_pkg::W)) dut (
        .clk          (clk),
        .rst_n        (vif.rst_n),
        .in_valid     (vif.in_valid),
        .streaming_in (vif.streaming_in),
        .out_valid    (vif.out_valid),
        .data_out     (vif.data_out),
        .max_of_5     (vif.max_of_5)
    );

    initial begin
        $dumpfile("max_of_5.vcd");
        $dumpvars(0, tb_top);
    end

    initial begin
        uvm_config_db#(virtual max5_if)::set(null, "uvm_test_top*", "vif", vif);
        run_test("max5_basic_test");
    end
endmodule
