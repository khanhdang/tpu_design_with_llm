// TPU top: controller + systolic array + input/output registers.
// On accept, both matrices are latched so later input changes cannot affect the
// transaction. During compute, boundary lanes are generated from the latched
// copies: A lane i carries A[i][step-i], B lane j carries B[step-j][j].
// The array result is copied into c_matrix on the capture edge and held until
// the next capture. Reset is synchronous and active low.
module tpu_top #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                        clk,
    input  logic                                        rst_n,
    input  logic                                        start,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_matrix,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_matrix,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0]  c_matrix,
    output logic                                        busy,
    output logic                                        done
);
    localparam int N      = ARRAY_SIZE;
    localparam int STEP_W = ($clog2(3*N-2) > 1) ? $clog2(3*N-2) : 1;

    logic              accept;
    logic              clear;
    logic              compute;
    logic              capture;
    logic [STEP_W-1:0] step;

    controller #(
        .ARRAY_SIZE(N)
    ) u_ctrl (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (start),
        .accept (accept),
        .clear  (clear),
        .compute(compute),
        .capture(capture),
        .busy   (busy),
        .done   (done),
        .step   (step)
    );

    // Input registers latched on accept; the transaction uses only these copies.
    logic [N*N*DATA_WIDTH-1:0] a_reg;
    logic [N*N*DATA_WIDTH-1:0] b_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            a_reg <= '0;
            b_reg <= '0;
        end else if (accept) begin
            a_reg <= a_matrix;
            b_reg <= b_matrix;
        end
    end

    // Skewed boundary lanes for the current step; zero outside the valid range
    // and whenever the array is not computing.
    logic [N*DATA_WIDTH-1:0] a_left;
    logic [N*DATA_WIDTH-1:0] b_top;
    integer                  s;
    integer                  kk;
    integer                  i;

    always @* begin
        a_left = '0;
        b_top  = '0;
        s      = step;
        if (compute) begin
            for (i = 0; i < N; i = i + 1) begin
                // Row lane i and column lane i share the same skew index kk.
                kk = s - i;
                if (kk >= 0 && kk < N) begin
                    a_left[i*DATA_WIDTH +: DATA_WIDTH] = a_reg[(i*N+kk)*DATA_WIDTH +: DATA_WIDTH];
                    b_top[i*DATA_WIDTH +: DATA_WIDTH]  = b_reg[(kk*N+i)*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end

    logic [N*N*ACC_WIDTH-1:0] c_bus;

    systolic_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .ARRAY_SIZE(N)
    ) u_array (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (clear),
        .en    (compute),
        .a_left(a_left),
        .b_top (b_top),
        .c     (c_bus)
    );

    // Published result: updated only on capture, zeroed by reset.
    always @(posedge clk) begin
        if (!rst_n)
            c_matrix <= '0;
        else if (capture)
            c_matrix <= c_bus;
    end
endmodule
