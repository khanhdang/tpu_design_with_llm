// Transaction sequencer: IDLE -> CLEAR -> RUN (3N-2 compute edges) -> CAPTURE -> IDLE.
// Phase outputs describe the action for the upcoming rising edge; done is a
// registered one-cycle pulse issued when CAPTURE completes.
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
    output logic [((ARRAY_SIZE > 1) ? $clog2(3*ARRAY_SIZE-2) : 1)-1:0] step
);

    localparam int N          = ARRAY_SIZE;
    localparam int LAST_STEP  = 3*N - 3;
    localparam int STEP_WIDTH = (N > 1) ? $clog2(3*N-2) : 1;   // max(1, $clog2(3N-2))

    typedef enum logic [1:0] {
        S_IDLE    = 2'd0,
        S_CLEAR   = 2'd1,
        S_RUN     = 2'd2,
        S_CAPTURE = 2'd3
    } state_t;

    state_t state;

    // Decode the action for the upcoming edge from the current state.
    assign busy    = (state != S_IDLE);
    assign accept  = (state == S_IDLE) && start;
    assign clear   = (state == S_CLEAR);
    assign compute = (state == S_RUN);
    assign capture = (state == S_CAPTURE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            step  <= '0;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    step <= '0;
                    if (start) state <= S_CLEAR;
                end
                S_CLEAR: begin
                    step  <= '0;
                    state <= S_RUN;
                end
                S_RUN: begin
                    if (step == STEP_WIDTH'(LAST_STEP)) begin
                        state <= S_CAPTURE;
                    end else begin
                        step <= step + 1'b1;
                    end
                end
                S_CAPTURE: begin
                    state <= S_IDLE;
                    done  <= 1'b1;
                    step  <= '0;
                end
                default: begin
                    state <= S_IDLE;
                    step  <= '0;
                end
            endcase
        end
    end

endmodule
