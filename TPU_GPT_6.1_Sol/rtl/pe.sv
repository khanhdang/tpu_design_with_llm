`timescale 1ns/1ps
module pe #(
    parameter integer DATA_WIDTH=8,
    parameter integer ACC_WIDTH=32
) (
    input wire clk, rst_n, clr, en,
    input wire signed [DATA_WIDTH-1:0] a_in, b_in,
    output reg signed [DATA_WIDTH-1:0] a_out, b_out,
    output wire signed [ACC_WIDTH-1:0] acc
);
    // The MAC samples this edge's inputs; forwarding adds exactly one hop.
    mac #(.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) accumulator (
        .clk(clk),.rst_n(rst_n),.clr(clr),.en(en),.a(a_in),.b(b_in),.acc(acc)
    );
    always @(posedge clk) begin
        if (!rst_n || clr) begin a_out <= '0; b_out <= '0; end
        else if (en) begin a_out <= a_in; b_out <= b_in; end
    end
endmodule
