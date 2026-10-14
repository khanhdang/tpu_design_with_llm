// N x N systolic array of PEs. A flows left to right, B flows top to bottom.
module systolic_array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                  clk,
    input  logic                                  rst_n,
    input  logic                                  clr,
    input  logic                                  en,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]      a_left,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]      b_top,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c
);

    localparam int N = ARRAY_SIZE;

    // a_wire[i][j] is the A input of PE(i,j); column N is the unused right edge.
    // b_wire[i][j] is the B input of PE(i,j); row N is the unused bottom edge.
    logic signed [DATA_WIDTH-1:0] a_wire [N][N+1];
    logic signed [DATA_WIDTH-1:0] b_wire [N+1][N];

    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : g_row
            assign a_wire[i][0] = a_left[i*DATA_WIDTH +: DATA_WIDTH];
        end
        for (j = 0; j < N; j++) begin : g_col
            assign b_wire[0][j] = b_top[j*DATA_WIDTH +: DATA_WIDTH];
        end

        for (i = 0; i < N; i++) begin : g_i
            for (j = 0; j < N; j++) begin : g_j
                logic signed [ACC_WIDTH-1:0] acc;
                pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_pe (
                    .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
                    .a_in(a_wire[i][j]),   .b_in(b_wire[i][j]),
                    .a_out(a_wire[i][j+1]), .b_out(b_wire[i+1][j]),
                    .acc(acc)
                );
                assign c[(i*N+j)*ACC_WIDTH +: ACC_WIDTH] = acc;
            end
        end
    endgenerate

endmodule
