module tpu_top #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_matrix,
    input  logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_matrix,
    output logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c_matrix,
    output logic busy,
    output logic done
);
    localparam int RUN_CYCLES = 3 * ARRAY_SIZE - 2;
    localparam int STEP_WIDTH = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES);

    logic accept;
    logic clear;
    logic compute;
    logic capture;
    logic [STEP_WIDTH-1:0] step;
    logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_latched;
    logic [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_latched;
    logic [ARRAY_SIZE*DATA_WIDTH-1:0] a_left;
    logic [ARRAY_SIZE*DATA_WIDTH-1:0] b_top;
    logic [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] array_c;

    controller #(
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .accept(accept),
        .clear(clear),
        .compute(compute),
        .capture(capture),
        .busy(busy),
        .done(done),
        .step(step)
    );

    systolic_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_array (
        .clk(clk),
        .rst_n(rst_n),
        .clr(clear),
        .en(compute),
        .a_left(a_left),
        .b_top(b_top),
        .c(array_c)
    );

    always_comb begin
        int i;
        int idx;

        a_left = '0;
        b_top = '0;

        if (compute) begin
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                idx = int'(step) - i;
                if ((idx >= 0) && (idx < ARRAY_SIZE)) begin
                    a_left[i*DATA_WIDTH +: DATA_WIDTH] =
                        a_latched[(i*ARRAY_SIZE + idx)*DATA_WIDTH +: DATA_WIDTH];
                end

                idx = int'(step) - i;
                if ((idx >= 0) && (idx < ARRAY_SIZE)) begin
                    b_top[i*DATA_WIDTH +: DATA_WIDTH] =
                        b_latched[(idx*ARRAY_SIZE + i)*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_latched <= '0;
            b_latched <= '0;
            c_matrix <= '0;
        end else begin
            if (accept) begin
                a_latched <= a_matrix;
                b_latched <= b_matrix;
            end

            if (capture) begin
                c_matrix <= array_c;
            end
        end
    end
endmodule
