`timescale 1ns/1ps

module tpu_top #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 32,
    parameter integer ARRAY_SIZE = 4
) (
    input  wire                                          clk,
    input  wire                                          rst_n,
    input  wire                                          start,
    input  wire [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0]    a_matrix,
    input  wire [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0]    b_matrix,
    output reg  [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0]     c_matrix,
    output wire                                          busy,
    output wire                                          done
);
    localparam integer STEP_WIDTH =
        (3*ARRAY_SIZE-2 <= 1) ? 1 : $clog2(3*ARRAY_SIZE-2);

    wire accept;
    wire array_clear;
    wire compute;
    wire capture;
    wire [STEP_WIDTH-1:0] step;
    wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] array_c;
    reg  [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_latched;
    reg  [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_latched;
    reg  [ARRAY_SIZE*DATA_WIDTH-1:0] a_left;
    reg  [ARRAY_SIZE*DATA_WIDTH-1:0] b_top;

    controller #(.ARRAY_SIZE(ARRAY_SIZE)) u_controller (
        .clk(clk), .rst_n(rst_n), .start(start), .accept(accept),
        .clear(array_clear), .compute(compute), .capture(capture),
        .busy(busy), .done(done), .step(step)
    );

    systolic_array #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)
    ) u_array (
        .clk(clk), .rst_n(rst_n), .clr(array_clear), .en(compute),
        .a_left(a_left), .b_top(b_top), .c(array_c)
    );

    integer lane;
    integer matrix_index;
    always @* begin
        a_left = {ARRAY_SIZE*DATA_WIDTH{1'b0}};
        b_top  = {ARRAY_SIZE*DATA_WIDTH{1'b0}};
        if (compute) begin
            for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin
                matrix_index = step - lane;
                if ((matrix_index >= 0) && (matrix_index < ARRAY_SIZE)) begin
                    a_left[lane*DATA_WIDTH +: DATA_WIDTH] =
                        a_latched[(lane*ARRAY_SIZE+matrix_index)*DATA_WIDTH +: DATA_WIDTH];
                    b_top[lane*DATA_WIDTH +: DATA_WIDTH] =
                        b_latched[(matrix_index*ARRAY_SIZE+lane)*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            a_latched <= {ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH{1'b0}};
            b_latched <= {ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH{1'b0}};
            c_matrix  <= {ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH{1'b0}};
        end else begin
            if (accept) begin
                a_latched <= a_matrix;
                b_latched <= b_matrix;
            end
            if (capture)
                c_matrix <= array_c;
        end
    end
endmodule
