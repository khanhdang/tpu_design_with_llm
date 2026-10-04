`timescale 1ns/1ps

module mac #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clr,
    input  wire                         en,
    input  wire signed [DATA_WIDTH-1:0] a,
    input  wire signed [DATA_WIDTH-1:0] b,
    output reg  signed [ACC_WIDTH-1:0]  acc
);
    localparam integer PRODUCT_WIDTH = 2 * DATA_WIDTH;

    wire signed [PRODUCT_WIDTH-1:0] product;
    wire signed [ACC_WIDTH-1:0] product_extended;

    assign product = a * b;
    assign product_extended =
        {{(ACC_WIDTH-PRODUCT_WIDTH){product[PRODUCT_WIDTH-1]}}, product};

    always @(posedge clk) begin
        if (!rst_n)
            acc <= {ACC_WIDTH{1'b0}};
        else if (clr)
            acc <= {ACC_WIDTH{1'b0}};
        else if (en)
            acc <= acc + product_extended;
    end
endmodule
