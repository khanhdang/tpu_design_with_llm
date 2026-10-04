module controller #(
    parameter int ARRAY_SIZE = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic accept,
    output logic clear,
    output logic compute,
    output logic capture,
    output logic busy,
    output logic done,
    output logic [((3*ARRAY_SIZE-2) <= 1 ? 1 : $clog2(3*ARRAY_SIZE-2))-1:0] step
);
    localparam int RUN_CYCLES = 3 * ARRAY_SIZE - 2;
    localparam int STEP_WIDTH = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES);
    localparam logic [STEP_WIDTH-1:0] LAST_STEP = RUN_CYCLES - 1;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_CLEAR,
        ST_RUN,
        ST_CAPTURE
    } state_t;

    state_t state;

    assign accept = rst_n && (state == ST_IDLE) && start;
    assign clear = (state == ST_CLEAR);
    assign compute = (state == ST_RUN);
    assign capture = (state == ST_CAPTURE);
    assign busy = (state != ST_IDLE);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            step <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    step <= '0;
                    if (start) begin
                        state <= ST_CLEAR;
                    end
                end

                ST_CLEAR: begin
                    state <= ST_RUN;
                    step <= '0;
                end

                ST_RUN: begin
                    if (step == LAST_STEP) begin
                        state <= ST_CAPTURE;
                    end else begin
                        step <= step + {{(STEP_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                ST_CAPTURE: begin
                    state <= ST_IDLE;
                    step <= '0;
                    done <= 1'b1;
                end

                default: begin
                    state <= ST_IDLE;
                    step <= '0;
                end
            endcase
        end
    end
endmodule
