// N x N output-stationary systolic array of PEs.
// A flows left to right, B flows top to bottom. Each PE accumulates its own
// C element; all accumulators are exposed in row-major order on c.
// clr clears the whole array; en advances every PE together.
module systolic_array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                       clk,
    input  logic                                       rst_n,
    input  logic                                       clr,
    input  logic                                       en,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]           a_left,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0]           b_top,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c
);
    localparam int N = ARRAY_SIZE;

    // Flat internal buses. PE(i,j) occupies slice index i*N+j.
    wire [N*N*DATA_WIDTH-1:0] a_in_bus;
    wire [N*N*DATA_WIDTH-1:0] a_out_bus;
    wire [N*N*DATA_WIDTH-1:0] b_in_bus;
    wire [N*N*DATA_WIDTH-1:0] b_out_bus;
    wire [N*N*ACC_WIDTH-1:0]  acc_bus;

    assign c = acc_bus;

    genvar i;
    genvar j;
    generate
        for (i = 0; i < N; i++) begin : g_row
            for (j = 0; j < N; j++) begin : g_col
                localparam int IDX = i * N + j;

                // A enters from the left edge of each row, then hops rightward.
                if (j == 0) begin : g_a_edge
                    assign a_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH] =
                        a_left[i*DATA_WIDTH +: DATA_WIDTH];
                end else begin : g_a_hop
                    assign a_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH] =
                        a_out_bus[(IDX-1)*DATA_WIDTH +: DATA_WIDTH];
                end

                // B enters from the top edge of each column, then hops downward.
                if (i == 0) begin : g_b_edge
                    assign b_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH] =
                        b_top[j*DATA_WIDTH +: DATA_WIDTH];
                end else begin : g_b_hop
                    assign b_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH] =
                        b_out_bus[((i-1)*N+j)*DATA_WIDTH +: DATA_WIDTH];
                end

                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_pe (
                    .clk  (clk),
                    .rst_n(rst_n),
                    .clr  (clr),
                    .en   (en),
                    .a_in (a_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH]),
                    .b_in (b_in_bus[IDX*DATA_WIDTH +: DATA_WIDTH]),
                    .a_out(a_out_bus[IDX*DATA_WIDTH +: DATA_WIDTH]),
                    .b_out(b_out_bus[IDX*DATA_WIDTH +: DATA_WIDTH]),
                    .acc  (acc_bus[IDX*ACC_WIDTH +: ACC_WIDTH])
                );
            end
        end
    endgenerate
endmodule
