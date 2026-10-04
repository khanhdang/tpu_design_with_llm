`timescale 1ns/1ps

module controller #(
    parameter integer ARRAY_SIZE = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire accept,
    output wire clear,
    output wire compute,
    output wire capture,
    output wire busy,
    output reg  done,
    output wire [(3*ARRAY_SIZE-2 <= 1 ? 1 : $clog2(3*ARRAY_SIZE-2))-1:0] step
);
    localparam integer STEP_WIDTH =
        (3*ARRAY_SIZE-2 <= 1) ? 1 : $clog2(3*ARRAY_SIZE-2);
    localparam integer LAST_STEP = 3*ARRAY_SIZE - 3;

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CLEAR   = 2'd1;
    localparam [1:0] RUN     = 2'd2;
    localparam [1:0] CAPTURE = 2'd3;

    reg [1:0] state;
    reg [STEP_WIDTH-1:0] step_reg;

    assign accept  = (state == IDLE) && start;
    assign clear   = (state == CLEAR);
    assign compute = (state == RUN);
    assign capture = (state == CAPTURE);
    assign busy    = (state != IDLE);
    assign step    = step_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            step_reg <= {STEP_WIDTH{1'b0}};
            done     <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    step_reg <= {STEP_WIDTH{1'b0}};
                    if (start)
                        state <= CLEAR;
                end
                CLEAR: begin
                    step_reg <= {STEP_WIDTH{1'b0}};
                    state <= RUN;
                end
                RUN: begin
                    if (step_reg == LAST_STEP) begin
                        state <= CAPTURE;
                    end else begin
                        step_reg <= step_reg + {{(STEP_WIDTH-1){1'b0}}, 1'b1};
                    end
                end
                CAPTURE: begin
                    state <= IDLE;
                    step_reg <= {STEP_WIDTH{1'b0}};
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    step_reg <= {STEP_WIDTH{1'b0}};
                end
            endcase
        end
    end
endmodule
