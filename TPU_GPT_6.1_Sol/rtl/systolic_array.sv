`timescale 1ns/1ps
module systolic_array #(
    parameter integer DATA_WIDTH=8,
    parameter integer ACC_WIDTH=32,
    parameter integer ARRAY_SIZE=4
) (
    input wire clk,rst_n,clr,en,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] a_left,b_top,
    output wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c
);
    wire signed [DATA_WIDTH-1:0] a_hop [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    wire signed [DATA_WIDTH-1:0] b_hop [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    genvar row,col;
    generate
        for(row=0;row<ARRAY_SIZE;row=row+1) begin: rows
            assign a_hop[row][0]=a_left[row*DATA_WIDTH +: DATA_WIDTH];
            assign b_hop[0][row]=b_top[row*DATA_WIDTH +: DATA_WIDTH];
            for(col=0;col<ARRAY_SIZE;col=col+1) begin: cols
                pe #(.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) cell_pe (
                    .clk(clk),.rst_n(rst_n),.clr(clr),.en(en),
                    .a_in(a_hop[row][col]),.b_in(b_hop[row][col]),
                    .a_out(a_hop[row][col+1]),.b_out(b_hop[row+1][col]),
                    .acc(c[(row*ARRAY_SIZE+col)*ACC_WIDTH +: ACC_WIDTH])
                );
            end
        end
    endgenerate
endmodule
