`timescale 1ns/1ps

module systolic_array #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 32,
    parameter integer ARRAY_SIZE = 4
) (
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      clr,
    input  wire                                      en,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0]          a_left,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0]          b_top,
    output wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c
);
    wire signed [DATA_WIDTH-1:0] a_forward [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire signed [DATA_WIDTH-1:0] b_forward [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire signed [ACC_WIDTH-1:0]  accumulators [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    genvar row, col;
    generate
        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin : gen_rows
            for (col = 0; col < ARRAY_SIZE; col = col + 1) begin : gen_cols
                wire signed [DATA_WIDTH-1:0] a_source;
                wire signed [DATA_WIDTH-1:0] b_source;

                if (col == 0)
                    assign a_source = $signed(a_left[row*DATA_WIDTH +: DATA_WIDTH]);
                else
                    assign a_source = a_forward[row][col-1];

                if (row == 0)
                    assign b_source = $signed(b_top[col*DATA_WIDTH +: DATA_WIDTH]);
                else
                    assign b_source = b_forward[row-1][col];

                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
                    .a_in(a_source), .b_in(b_source),
                    .a_out(a_forward[row][col]),
                    .b_out(b_forward[row][col]),
                    .acc(accumulators[row][col])
                );

                assign c[(row*ARRAY_SIZE+col)*ACC_WIDTH +: ACC_WIDTH] =
                    accumulators[row][col];
            end
        end
    endgenerate
endmodule
