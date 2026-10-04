`timescale 1ns/1ps
module tpu_top #(
    parameter integer DATA_WIDTH=8,
    parameter integer ACC_WIDTH=32,
    parameter integer ARRAY_SIZE=4
) (
    input wire clk,rst_n,start,
    input wire [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_matrix,b_matrix,
    output reg [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] c_matrix,
    output wire busy,done
);
    localparam integer STEP_WIDTH=(3*ARRAY_SIZE-2>1)?$clog2(3*ARRAY_SIZE-2):1;
    reg [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] saved_a,saved_b;
    wire accept,clear,compute,capture;
    wire [STEP_WIDTH-1:0] step;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] a_left,b_top;
    wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] array_c;

    controller #(.ARRAY_SIZE(ARRAY_SIZE)) sequencer (
        .clk(clk),.rst_n(rst_n),.start(start),.accept(accept),.clear(clear),
        .compute(compute),.capture(capture),.busy(busy),.done(done),.step(step)
    );
    systolic_array #(.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH),.ARRAY_SIZE(ARRAY_SIZE)) array (
        .clk(clk),.rst_n(rst_n),.clr(clear),.en(compute),
        .a_left(a_left),.b_top(b_top),.c(array_c)
    );

    // Skew each lane by its row/column index; out-of-range lanes are zero.
    genvar lane;
    generate
        for(lane=0;lane<ARRAY_SIZE;lane=lane+1) begin: lanes
            assign a_left[lane*DATA_WIDTH +: DATA_WIDTH]=
                (compute && step>=lane && step<lane+ARRAY_SIZE) ?
                saved_a[(lane*ARRAY_SIZE+step-lane)*DATA_WIDTH +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
            assign b_top[lane*DATA_WIDTH +: DATA_WIDTH]=
                (compute && step>=lane && step<lane+ARRAY_SIZE) ?
                saved_b[((step-lane)*ARRAY_SIZE+lane)*DATA_WIDTH +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
        end
    endgenerate

    always @(posedge clk) begin
        if(!rst_n) begin saved_a<='0; saved_b<='0; c_matrix<='0; end
        else begin
            if(accept) begin saved_a<=a_matrix; saved_b<=b_matrix; end
            // Separate capture edge follows the final accumulator update.
            if(capture) c_matrix<=array_c;
        end
    end
endmodule
