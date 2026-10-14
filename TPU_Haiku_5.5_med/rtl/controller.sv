// Transaction controller for the systolic array.
// IDLE -> CLEAR -> RUN (3*N-2 compute edges, step 0..3*N-3) -> CAPTURE -> IDLE.
// accept, clear, compute, capture, and busy are decoded from the current state
// and describe the upcoming rising edge. done is a registered one-cycle pulse
// asserted on the edge that leaves CAPTURE. Reset is synchronous and active low.
module controller #(
    parameter int ARRAY_SIZE = 4
) (
    input  logic                                        clk,
    input  logic                                        rst_n,
    input  logic                                        start,
    output logic                                        accept,
    output logic                                        clear,
    output logic                                        compute,
    output logic                                        capture,
    output logic                                        busy,
    output logic                                        done,
    output logic [(($clog2(3*ARRAY_SIZE-2) > 1) ? $clog2(3*ARRAY_SIZE-2) : 1)-1:0] step
);
    localparam int STEP_W    = ($clog2(3*ARRAY_SIZE-2) > 1) ? $clog2(3*ARRAY_SIZE-2) : 1;
    localparam int STEP_LAST = 3*ARRAY_SIZE - 3;

    localparam logic [1:0] S_IDLE    = 2'd0;
    localparam logic [1:0] S_CLEAR   = 2'd1;
    localparam logic [1:0] S_RUN     = 2'd2;
    localparam logic [1:0] S_CAPTURE = 2'd3;

    logic [1:0] state;

    // Decoded for the upcoming edge; no control stays high outside its state.
    assign accept  = (state == S_IDLE) && start;
    assign clear   = (state == S_CLEAR);
    assign compute = (state == S_RUN);
    assign capture = (state == S_CAPTURE);
    assign busy    = (state != S_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            step  <= '0;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start)
                        state <= S_CLEAR;
                end
                S_CLEAR: begin
                    state <= S_RUN;
                    step  <= '0;
                end
                S_RUN: begin
                    if (step == STEP_W'(STEP_LAST))
                        state <= S_CAPTURE;
                    else
                        step <= step + STEP_W'(1);
                end
                S_CAPTURE: begin
                    state <= S_IDLE;
                    step  <= '0;
                    done  <= 1'b1;
                end
                default: begin
                    state <= S_IDLE;
                    step  <= '0;
                end
            endcase
        end
    end
endmodule
