module systolic_array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    input  logic en,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0] a_left,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0] b_top,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c
);
    genvar row;
    genvar col;

    logic signed [DATA_WIDTH-1:0] a_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    logic signed [DATA_WIDTH-1:0] b_link [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    logic signed [ACC_WIDTH-1:0] acc_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    generate
        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin : gen_a_input
            assign a_link[row][0] = $signed(a_left[row*DATA_WIDTH +: DATA_WIDTH]);
        end

        for (col = 0; col < ARRAY_SIZE; col = col + 1) begin : gen_b_input
            assign b_link[0][col] = $signed(b_top[col*DATA_WIDTH +: DATA_WIDTH]);
        end

        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin : gen_rows
            for (col = 0; col < ARRAY_SIZE; col = col + 1) begin : gen_cols
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clr(clr),
                    .en(en),
                    .a_in(a_link[row][col]),
                    .b_in(b_link[row][col]),
                    .a_out(a_link[row][col+1]),
                    .b_out(b_link[row+1][col]),
                    .acc(acc_link[row][col])
                );

                assign c[(row*ARRAY_SIZE + col)*ACC_WIDTH +: ACC_WIDTH] = acc_link[row][col];
            end
        end
    endgenerate
endmodule
