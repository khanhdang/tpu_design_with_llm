// Transaction controller: IDLE -> CLEAR -> RUN (3*N-2 compute edges) -> CAPTURE -> IDLE.
// accept/clear/compute/capture/busy are decoded from the current state and
// describe the action of the upcoming rising edge. done is a registered
// one-cycle pulse asserted after the capture edge.
module controller #(
    parameter int ARRAY_SIZE = 4,
    localparam int STEP_W = ($clog2(3*ARRAY_SIZE-2) > 1) ? $clog2(3*ARRAY_SIZE-2) : 1
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    output logic              accept,
    output logic              clear,
    output logic              compute,
    output logic              capture,
    output logic              busy,
    output logic              done,
    output logic [STEP_W-1:0] step
);

    localparam logic [STEP_W-1:0] LAST_STEP = STEP_W'(3*ARRAY_SIZE - 3);

    typedef enum logic [1:0] {
        S_IDLE    = 2'd0,
        S_CLEAR   = 2'd1,
        S_RUN     = 2'd2,
        S_CAPTURE = 2'd3
    } state_t;

    state_t state;

    assign busy    = (state != S_IDLE);
    assign accept  = (state == S_IDLE) && start;
    assign clear   = (state == S_CLEAR);
    assign compute = (state == S_RUN);
    assign capture = (state == S_CAPTURE);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            step  <= '0;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) state <= S_CLEAR;
                end
                S_CLEAR: begin
                    state <= S_RUN;
                    step  <= '0;
                end
                S_RUN: begin
                    if (step == LAST_STEP) begin
                        state <= S_CAPTURE;
                    end else begin
                        step <= step + 1'b1;
                    end
                end
                S_CAPTURE: begin
                    state <= S_IDLE;
                    done  <= 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
