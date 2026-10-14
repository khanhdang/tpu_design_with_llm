// TPU top: latches A and B on accept, feeds skewed lanes into the systolic
// array during compute, and publishes C on capture.
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

    localparam int N          = ARRAY_SIZE;
    localparam int STEP_WIDTH = (N > 1) ? $clog2(3*N-2) : 1;

    logic                    accept, clear, compute, capture;
    logic [STEP_WIDTH-1:0]   step;

    logic [N*N*DATA_WIDTH-1:0] a_lat, b_lat;
    logic [N*DATA_WIDTH-1:0]   a_left, b_top;
    logic [N*N*ACC_WIDTH-1:0]  c_array;

    controller #(.ARRAY_SIZE(N)) u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start),
        .accept(accept), .clear(clear), .compute(compute), .capture(capture),
        .busy(busy), .done(done), .step(step)
    );

    systolic_array #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(N)) u_array (
        .clk(clk), .rst_n(rst_n), .clr(clear), .en(compute),
        .a_left(a_left), .b_top(b_top), .c(c_array)
    );

    // Skewed boundary lanes from the latched matrices; zero outside range / when idle.
    always_comb begin
        a_left = '0;
        b_top  = '0;
        if (compute) begin
            for (int i = 0; i < N; i++) begin
                if (int'(step) - i >= 0 && int'(step) - i < N)
                    a_left[i*DATA_WIDTH +: DATA_WIDTH] =
                        a_lat[(i*N + (int'(step) - i))*DATA_WIDTH +: DATA_WIDTH];
            end
            for (int j = 0; j < N; j++) begin
                if (int'(step) - j >= 0 && int'(step) - j < N)
                    b_top[j*DATA_WIDTH +: DATA_WIDTH] =
                        b_lat[((int'(step) - j)*N + j)*DATA_WIDTH +: DATA_WIDTH];
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            a_lat    <= '0;
            b_lat    <= '0;
            c_matrix <= '0;
        end else begin
            if (accept) begin
                a_lat <= a_matrix;
                b_lat <= b_matrix;
            end
            if (capture)
                c_matrix <= c_array;
        end
    end

endmodule
