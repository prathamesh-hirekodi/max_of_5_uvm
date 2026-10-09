`timescale 1ns/1ps
// Interface between the UVM testbench and the max_of_5 DUT
interface max5_if #(parameter W = 8) (input logic clk);
    logic         rst_n;
    logic         in_valid;
    logic [W-1:0] streaming_in;
    logic         out_valid;
    logic [W-1:0] data_out;
    logic [W-1:0] max_of_5;
endinterface
