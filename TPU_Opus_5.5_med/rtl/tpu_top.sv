// TPU top: latches A and B on accept, streams skewed lanes into the systolic
// array during RUN, and publishes the array accumulators into c_matrix on capture.
module tpu_top #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                       clk,
    input  logic                                       rst_n,
    input  logic                                       start,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_matrix,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_matrix,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0]  c_matrix,
    output logic                                       busy,
    output logic                                       done
);

    localparam int N      = ARRAY_SIZE;
    localparam int STEP_W = ($clog2(3*N-2) > 1) ? $clog2(3*N-2) : 1;

    logic              accept, clear, compute, capture;
    logic [STEP_W-1:0] step;

    logic [N*N*DATA_WIDTH-1:0] a_reg, b_reg;
    logic [N*DATA_WIDTH-1:0]   a_left, b_top;
    logic [N*N*ACC_WIDTH-1:0]  c_array;

    controller #(.ARRAY_SIZE(N)) u_ctrl (
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
        .c     (c_array)
    );

    // Input matrix latches.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_reg <= '0;
            b_reg <= '0;
        end else if (accept) begin
            a_reg <= a_matrix;
            b_reg <= b_matrix;
        end
    end

    // Skewed boundary lanes from the latched matrices:
    //   a_left lane i = A[i][step-i], b_top lane j = B[step-j][j], zero otherwise.
    always_comb begin
        a_left = '0;
        b_top  = '0;
        if (compute) begin
            for (int i = 0; i < N; i++) begin
                for (int k = 0; k < N; k++) begin
                    if (step == STEP_W'(i + k)) begin
                        a_left[i*DATA_WIDTH +: DATA_WIDTH] = a_reg[(i*N + k)*DATA_WIDTH +: DATA_WIDTH];
                        b_top [i*DATA_WIDTH +: DATA_WIDTH] = b_reg[(k*N + i)*DATA_WIDTH +: DATA_WIDTH];
                    end
                end
            end
        end
    end

    // Published result register.
    always_ff @(posedge clk) begin
        if (!rst_n)
            c_matrix <= '0;
        else if (capture)
            c_matrix <= c_array;
    end

endmodule
