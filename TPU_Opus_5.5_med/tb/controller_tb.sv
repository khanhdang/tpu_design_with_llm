// Self-checking testbench for controller.
// N=1, N=2 and N=4 harnesses each check a scripted, independently sequenced
// expectation for every cycle of every transaction, plus an always-on monitor
// (exclusive phases, accept only when idle, done exactly one cycle after each
// capture edge, compute edges per transaction = 3*N-2).

module controller_harness #(
    parameter int ARRAY_SIZE = 4,
    parameter int EXP_EDGES  = 10,   // expected compute edges per transaction
    parameter int SEED       = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);

    localparam int N = ARRAY_SIZE;
    localparam int STEP_W = ($clog2(3*N-2) > 1) ? $clog2(3*N-2) : 1;

    logic              rst_n, start;
    logic              accept, clear, compute, capture, busy, done;
    logic [STEP_W-1:0] step;
    integer            seed;
    integer            txn_count;

    controller #(.ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .accept(accept), .clear(clear), .compute(compute), .capture(capture),
        .busy(busy), .done(done), .step(step)
    );

    // ---------------------------------------------------------------- scripted checks
    task automatic fail_msg(input string what);
        errors = errors + 1;
        $display("FAIL CONTROLLER[N=%0d] %s @%0t: rst_n=%b start=%b | accept=%b clear=%b compute=%b capture=%b busy=%b done=%b step=%0d (txn=%0d seed=%0d)",
                 N, what, $time, rst_n, start, accept, clear, compute, capture, busy, done,
                 step, txn_count, SEED);
    endtask

    // Drive one cycle on the falling edge, check the decoded outputs for the
    // upcoming rising edge, then let that edge happen.
    task automatic expect_cycle(input logic r, input logic s,
                                input logic e_accept, input logic e_clear,
                                input logic e_compute, input logic e_capture,
                                input logic e_busy, input logic e_done,
                                input integer e_step, input string what);
        @(negedge clk);
        rst_n = r; start = s;
        #1;
        tests = tests + 1;
        if (accept !== e_accept || clear !== e_clear || compute !== e_compute ||
            capture !== e_capture || busy !== e_busy || done !== e_done ||
            (e_compute && step !== STEP_W'(e_step))) begin
            fail_msg(what);
            $display("     expected accept=%b clear=%b compute=%b capture=%b busy=%b done=%b step=%0d",
                     e_accept, e_clear, e_compute, e_capture, e_busy, e_done, e_step);
        end
        @(posedge clk);
    endtask

    task automatic idle_cycle(input logic s, input logic e_done, input string what);
        expect_cycle(1'b1, s, s, 1'b0, 1'b0, 1'b0, 1'b0, e_done, 0, what);
    endtask

    // Busy-phase start value: 0, 1, or random depending on mode.
    function automatic logic busy_start(input integer mode);
        case (mode)
            0:       return 1'b0;
            1:       return 1'b1;
            default: return $random(seed);
        endcase
    endfunction

    // Accept cycle through the capture cycle. first_done is the expected done
    // value during the accept cycle (1 for a back-to-back request).
    task automatic transaction(input logic first_done, input integer start_mode);
        integer t;
        txn_count = txn_count + 1;
        idle_cycle(1'b1, first_done, "accept");
        expect_cycle(1'b1, busy_start(start_mode), 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0, "clear");
        for (t = 0; t < EXP_EDGES; t = t + 1)
            expect_cycle(1'b1, busy_start(start_mode), 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t, "run");
        expect_cycle(1'b1, busy_start(start_mode), 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 0, "capture");
    endtask

    // ---------------------------------------------------------------- monitor
    logic   prev_capture_edge;
    integer edges_this_txn;
    integer done_count;

    initial begin
        prev_capture_edge = 1'b0;
        edges_this_txn    = 0;
        done_count        = 0;
    end

    always @(posedge clk) begin
        // Values sampled here are the pre-edge decoded actions.
        tests = tests + 1;
        if ((clear + compute + capture) > 1 || (accept && busy) ||
            (busy !== (clear || compute || capture))) begin
            fail_msg("monitor: overlapping or inconsistent phases");
        end
        if (!rst_n) begin
            edges_this_txn    = 0;
            prev_capture_edge = 1'b0;
        end else begin
            if (accept)  edges_this_txn = 0;
            if (compute) edges_this_txn = edges_this_txn + 1;
            prev_capture_edge = capture;
        end
        #1;
        tests = tests + 1;
        if (done !== prev_capture_edge) fail_msg("monitor: done is not exactly one cycle after capture");
        if (done === 1'b1) begin
            done_count = done_count + 1;
            tests = tests + 1;
            if (edges_this_txn !== EXP_EDGES) begin
                errors = errors + 1;
                $display("FAIL CONTROLLER[N=%0d] compute edges=%0d expected=%0d (txn=%0d)",
                         N, edges_this_txn, EXP_EDGES, txn_count);
            end
        end
    end

    // ---------------------------------------------------------------- sequence
    integer i, t, done_before;

    initial begin
        tests     = 0;
        errors    = 0;
        finished  = 1'b0;
        seed      = SEED;
        txn_count = 0;
        rst_n = 1'b0; start = 1'b0;

        // Reset, including with start asserted.
        // The state is unknown before the first reset edge, so that edge is unchecked.
        @(negedge clk);
        rst_n = 1'b0; start = 1'b1;
        @(posedge clk);
        expect_cycle(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0, "reset with start");
        idle_cycle(1'b0, 1'b0, "idle after reset");
        idle_cycle(1'b0, 1'b0, "idle after reset 2");

        // Single transaction, start low while busy.
        transaction(1'b0, 0);
        idle_cycle(1'b0, 1'b1, "done pulse");
        idle_cycle(1'b0, 1'b0, "done cleared");
        idle_cycle(1'b0, 1'b0, "stay idle");

        // Requests while busy are ignored (start held high during busy phases).
        transaction(1'b0, 1);
        idle_cycle(1'b0, 1'b1, "done after ignored requests");
        idle_cycle(1'b0, 1'b0, "idle after ignored requests");

        // Random start while busy.
        transaction(1'b0, 2);
        idle_cycle(1'b0, 1'b1, "done after random requests");

        // Consecutive transactions: new request on the first idle edge after completion.
        transaction(1'b0, 0);
        transaction(1'b1, 0);
        transaction(1'b1, 1);
        idle_cycle(1'b0, 1'b1, "done after back-to-back");
        idle_cycle(1'b0, 1'b0, "idle after back-to-back");

        // Reset in the middle of RUN aborts without done.
        done_before = done_count;
        txn_count = txn_count + 1;
        idle_cycle(1'b1, 1'b0, "accept before reset");
        expect_cycle(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0, "clear before reset");
        for (t = 0; t < (EXP_EDGES - 1) / 2; t = t + 1)
            expect_cycle(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t, "run before reset");
        expect_cycle(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, (EXP_EDGES - 1) / 2,
                     "reset asserted during run");
        for (i = 0; i < 2 * EXP_EDGES + 4; i = i + 1)
            idle_cycle(1'b0, 1'b0, "idle after reset during run");
        tests = tests + 1;
        if (done_count !== done_before) begin
            errors = errors + 1;
            $display("FAIL CONTROLLER[N=%0d] done pulsed after reset abort", N);
        end

        // Reset during CAPTURE also aborts without done.
        txn_count = txn_count + 1;
        idle_cycle(1'b1, 1'b0, "accept before capture reset");
        expect_cycle(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0, "clear");
        for (t = 0; t < EXP_EDGES; t = t + 1)
            expect_cycle(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t, "run");
        expect_cycle(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 0, "reset during capture");
        idle_cycle(1'b0, 1'b0, "no done after capture reset");
        idle_cycle(1'b0, 1'b0, "idle");

        // Reset during CLEAR.
        idle_cycle(1'b1, 1'b0, "accept before clear reset");
        expect_cycle(1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0, "reset during clear");
        idle_cycle(1'b0, 1'b0, "idle after clear reset");

        // Recovery: normal transactions after resets.
        transaction(1'b0, 2);
        transaction(1'b1, 2);
        idle_cycle(1'b0, 1'b1, "final done");
        idle_cycle(1'b0, 1'b0, "final idle");

        tests = tests + 1;
        if (done_count !== 8) begin
            errors = errors + 1;
            $display("FAIL CONTROLLER[N=%0d] completed transactions=%0d expected=8", N, done_count);
        end

        finished = 1'b1;
    end

endmodule

module controller_tb;

    localparam int MAX_CYCLES = 2000;

    logic   clk = 1'b0;
    always #5 clk = ~clk;

    integer t1, e1, t2, e2, t4, e4;
    logic   f1, f2, f4;
    integer cycles = 0;
    logic   reported = 1'b0;

    controller_harness #(.ARRAY_SIZE(1), .EXP_EDGES(1),  .SEED(32'h0C01)) h_n1 (
        .clk(clk), .tests(t1), .errors(e1), .finished(f1)
    );
    controller_harness #(.ARRAY_SIZE(2), .EXP_EDGES(4),  .SEED(32'h0C02)) h_n2 (
        .clk(clk), .tests(t2), .errors(e2), .finished(f2)
    );
    controller_harness #(.ARRAY_SIZE(4), .EXP_EDGES(10), .SEED(32'h0C04)) h_n4 (
        .clk(clk), .tests(t4), .errors(e4), .finished(f4)
    );

    initial begin
        $dumpfile("sim/controller_tb.vcd");
        $dumpvars(0, controller_tb);
    end

    task automatic summary(input integer tests, input integer errors);
        if (!reported) begin
            reported = 1'b1;
            $display("========================================");
            if (errors == 0 && tests > 0) $display("CONTROLLER TEST RESULT: PASS");
            else                          $display("CONTROLLER TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $display("========================================");
            $finish;
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (cycles >= MAX_CYCLES) begin
            $display("FAIL watchdog: timeout after %0d cycles", cycles);
            summary(t1 + t2 + t4, e1 + e2 + e4 + 1);
        end
    end

    initial begin
        wait (f1 === 1'b1 && f2 === 1'b1 && f4 === 1'b1);
        #1;
        $display("CONTROLLER config N=1: checks=%0d mismatches=%0d", t1, e1);
        $display("CONTROLLER config N=2: checks=%0d mismatches=%0d", t2, e2);
        $display("CONTROLLER config N=4: checks=%0d mismatches=%0d", t4, e4);
        summary(t1 + t2 + t4, e1 + e2 + e4);
    end

endmodule
