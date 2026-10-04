`timescale 1ns/1ps
module mac #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH = 32
) (
    input wire clk, rst_n, clr, en,
    input wire signed [DATA_WIDTH-1:0] a, b,
    output reg signed [ACC_WIDTH-1:0] acc
);
    wire signed [2*DATA_WIDTH-1:0] product = a * b;
    wire signed [ACC_WIDTH-1:0] extended_product =
        {{(ACC_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};

    always @(posedge clk) begin
        if (!rst_n) acc <= '0;
        else if (clr) acc <= '0;
        else if (en) acc <= acc + extended_product;
    end
endmodule
