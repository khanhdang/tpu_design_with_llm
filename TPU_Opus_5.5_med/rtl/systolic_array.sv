// N x N output-stationary systolic array.
// A enters on the left (lane i -> row i) and moves right; B enters on the top
// (lane j -> column j) and moves down. Each PE(i,j) accumulates C[i][j].
// c exposes all accumulators in row-major order.
module systolic_array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                          clk,
    input  logic                                          rst_n,
    input  logic                                          clr,
    input  logic                                          en,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]              a_left,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]              b_top,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0]    c
);

    localparam int N = ARRAY_SIZE;

    // Horizontal A links: row i, column position 0..N (position 0 is the left edge).
    logic [N*(N+1)*DATA_WIDTH-1:0] a_link;
    // Vertical B links: row position 0..N (position 0 is the top edge), column j.
    logic [(N+1)*N*DATA_WIDTH-1:0] b_link;

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_left
            assign a_link[(i*(N+1))*DATA_WIDTH +: DATA_WIDTH] = a_left[i*DATA_WIDTH +: DATA_WIDTH];
        end
        for (j = 0; j < N; j = j + 1) begin : g_top
            assign b_link[j*DATA_WIDTH +: DATA_WIDTH] = b_top[j*DATA_WIDTH +: DATA_WIDTH];
        end

        for (i = 0; i < N; i = i + 1) begin : g_row
            for (j = 0; j < N; j = j + 1) begin : g_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_pe (
                    .clk  (clk),
                    .rst_n(rst_n),
                    .clr  (clr),
                    .en   (en),
                    .a_in (a_link[(i*(N+1) + j)*DATA_WIDTH +: DATA_WIDTH]),
                    .b_in (b_link[(i*N + j)*DATA_WIDTH +: DATA_WIDTH]),
                    .a_out(a_link[(i*(N+1) + j + 1)*DATA_WIDTH +: DATA_WIDTH]),
                    .b_out(b_link[((i+1)*N + j)*DATA_WIDTH +: DATA_WIDTH]),
                    .acc  (c[(i*N + j)*ACC_WIDTH +: ACC_WIDTH])
                );
            end
        end
    endgenerate

endmodule
