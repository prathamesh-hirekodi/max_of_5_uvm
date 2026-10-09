`timescale 1ns/1ps
// max_of_5 : streaming sliding-window maximum over the last 5 samples.
//
// Each cycle with in_valid=1, streaming_in is accepted. One cycle later:
//   out_valid = 1
//   data_out  = the accepted sample (pass-through)
//   max_of_5  = max of that sample and the 4 samples before it
// Before 5 samples have arrived, the empty window slots hold 0, so the
// output is just the max of the samples seen so far (unsigned data).
module max_of_5 #(
    parameter W = 8
) (
    input  wire         clk,
    input  wire         rst_n,          // async, active low
    input  wire         in_valid,
    input  wire [W-1:0] streaming_in,
    output reg          out_valid,
    output reg  [W-1:0] data_out,
    output reg  [W-1:0] max_of_5
);

    // previous 4 samples (win0 = newest)
    reg [W-1:0] win0, win1, win2, win3;

    // max of the current input and the 4 previous samples
    wire [W-1:0] m01 = (streaming_in > win0) ? streaming_in : win0;
    wire [W-1:0] m23 = (win1 > win2) ? win1 : win2;
    wire [W-1:0] m03 = (m01 > m23) ? m01 : m23;
    wire [W-1:0] mx  = (m03 > win3) ? m03 : win3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            win0 <= 0; win1 <= 0; win2 <= 0; win3 <= 0;
            out_valid <= 1'b0;
            data_out  <= 0;
            max_of_5  <= 0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                win0     <= streaming_in;
                win1     <= win0;
                win2     <= win1;
                win3     <= win2;
                data_out <= streaming_in;
                max_of_5 <= mx;
            end
        end
    end

endmodule
