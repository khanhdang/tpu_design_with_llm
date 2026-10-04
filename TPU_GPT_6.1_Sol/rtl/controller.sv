`timescale 1ns/1ps
module controller #(
    parameter integer ARRAY_SIZE=4,
    localparam integer STEP_WIDTH=(3*ARRAY_SIZE-2>1) ? $clog2(3*ARRAY_SIZE-2) : 1
) (
    input wire clk,rst_n,start,
    output wire accept,clear,compute,capture,busy,
    output reg done,
    output reg [STEP_WIDTH-1:0] step
);
    localparam integer COMPUTE_EDGES=3*ARRAY_SIZE-2;
    typedef enum logic [1:0] {IDLE,CLEAR,RUN,CAPTURE} state_t;
    state_t state;
    assign accept=(state==IDLE) && start;
    assign clear=(state==CLEAR);
    assign compute=(state==RUN);
    assign capture=(state==CAPTURE);
    assign busy=(state!=IDLE);

    always @(posedge clk) begin
        if(!rst_n) begin state<=IDLE; step<='0; done<=0; end
        else begin
            done<=0;
            case(state)
                IDLE: if(start) state<=CLEAR;
                CLEAR: begin state<=RUN; step<='0; end
                RUN: begin
                    if(step==COMPUTE_EDGES-1) state<=CAPTURE;
                    else step<=step+1'b1;
                end
                CAPTURE: begin state<=IDLE; done<=1; end
                default: begin state<=IDLE; step<='0; end
            endcase
        end
    end
endmodule
