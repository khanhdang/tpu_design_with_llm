// Self-checking controller testbench: N=1, N=2, N=4 with an independent
// cycle-based timing reference.

module ctl_case #(
    parameter int N        = 4,
    parameter int SEED     = 1,
    parameter int NRANDOM  = 1500
) (
    input  logic clk,
    output logic done_tb,
    output int   tests,
    output int   errors
);
    localparam int SW = (N > 1) ? $clog2(3*N-2) : 1;
    localparam int COMPUTE_EDGES = 3*N - 2;

    logic          rst_n, start;
    logic          accept, clear, compute, capture, busy, done;
    logic [SW-1:0] step;

    controller #(.ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .accept(accept), .clear(clear),
        .compute(compute), .capture(capture), .busy(busy), .done(done), .step(step));

    // Reference: phase = 0 idle, 1 clear, 2 run, 3 capture; cycle counter in RUN.
    int  r_phase, r_cnt;
    logic r_done;
    int  seed_v;
    int  compute_seen;       // compute-high cycles in the current transaction
    int  transactions;       // completed transactions

    task automatic expect1(input string what, input logic got, input logic exp);
        tests++;
        if (got !== exp) begin
            errors++;
            $display("FAIL [%0s] N=%0d phase=%0d cnt=%0d start=%b rst_n=%b: expected=%b got=%b",
                     what, N, r_phase, r_cnt, start, rst_n, exp, got);
        end
    endtask

    // Check all outputs for the upcoming edge (inputs already driven).
    task automatic check_outputs();
        expect1("busy",    busy,    r_phase != 0);
        expect1("accept",  accept,  r_phase == 0 && start);
        expect1("clear",   clear,   r_phase == 1);
        expect1("compute", compute, r_phase == 2);
        expect1("capture", capture, r_phase == 3);
        expect1("done",    done,    r_done);
        // clear, compute and capture never overlap.
        expect1("exclusive", (clear + compute + capture) <= 1, 1'b1);
        if (r_phase == 2) begin
            tests++;
            if (step !== SW'(r_cnt)) begin
                errors++;
                $display("FAIL [step] N=%0d expected=%0d got=%0d", N, r_cnt, step);
            end
        end
        // done and busy are never both high (done is the first idle cycle).
        expect1("done/busy", (done && busy), 1'b0);
    endtask

    // Advance the reference model one rising edge, using the same inputs.
    task automatic step_reference();
        if (!rst_n) begin
            r_phase = 0; r_cnt = 0; r_done = 0;
        end else begin
            r_done = 0;
            case (r_phase)
                0: if (start) r_phase = 1;
                1: begin r_phase = 2; r_cnt = 0; end
                2: begin
                    if (r_cnt == COMPUTE_EDGES - 1) r_phase = 3;
                    else r_cnt++;
                end
                3: begin r_phase = 0; r_done = 1; end
            endcase
        end
    endtask

    // One clock cycle with given inputs; counts compute edges per transaction.
    task automatic cycle(input logic r_n, input logic s);
        @(negedge clk);
        rst_n = r_n; start = s;
        #1;
        check_outputs();
        if (!r_n) compute_seen = 0;
        else if (compute) compute_seen++;
        @(posedge clk);
        step_reference();
        // Per-transaction compute-edge count, checked when done is about to show.
        if (r_n && r_done) begin
            tests++;
            if (compute_seen !== COMPUTE_EDGES) begin
                errors++;
                $display("FAIL [compute edges] N=%0d expected=%0d got=%0d", N, COMPUTE_EDGES, compute_seen);
            end
            compute_seen = 0;
            transactions++;
        end
    endtask

    task automatic idle(input int n);
        repeat (n) cycle(1'b1, 1'b0);
    endtask

    int guard;

    initial begin
        done_tb = 0; tests = 0; errors = 0; seed_v = SEED;
        rst_n = 0; start = 0; r_phase = 0; r_cnt = 0; r_done = 0;
        compute_seen = 0; transactions = 0;

        // Reset, then idle.
        cycle(1'b0, 1'b0);
        cycle(1'b0, 1'b1);       // start ignored in reset
        idle(3);

        // Single transaction with a one-cycle start pulse.
        cycle(1'b1, 1'b1);
        idle(3*N + 6);

        // Start held high through the whole transaction (ignored while busy),
        // then a second back-to-back transaction is accepted when idle.
        repeat (2*(3*N + 4)) cycle(1'b1, 1'b1);
        cycle(1'b1, 1'b0);
        idle(3*N + 6);

        // Start pulses while busy are ignored.
        cycle(1'b1, 1'b1);
        repeat (3*N + 4) begin cycle(1'b1, 1'b0); cycle(1'b1, 1'b1); end
        idle(3*N + 6);

        // Reset during CLEAR, RUN (several points) and CAPTURE.
        for (int k = 1; k <= 3*N + 1; k++) begin
            cycle(1'b1, 1'b1);
            repeat (k) cycle(1'b1, 1'b0);
            cycle(1'b0, 1'b0);
            idle(2);
            // Consecutive transaction after abort.
            cycle(1'b1, 1'b1);
            idle(3*N + 4);
        end

        // Random start/reset activity checked against the reference.
        for (int i = 0; i < NRANDOM; i++) begin
            logic [7:0] r;
            r = 8'($random(seed_v));
            cycle(r > 8'd3, (r[7:6] != 2'b00) ? r[0] : 1'b1);
        end
        // Drain and finish idle.
        idle(3*N + 6);
        tests++;
        if (busy !== 1'b0) begin errors++; $display("FAIL [final idle] N=%0d busy=%b", N, busy); end
        tests++;
        if (transactions < 3) begin errors++; $display("FAIL [transactions] N=%0d only %0d completed", N, transactions); end
        done_tb = 1;
    end
endmodule

module controller_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic d1, d2, d4;
    int   t1, e1, t2, e2, t4, e4;

    ctl_case #(.N(1), .SEED(32'h1001)) u_n1 (.clk(clk), .done_tb(d1), .tests(t1), .errors(e1));
    ctl_case #(.N(2), .SEED(32'h1002)) u_n2 (.clk(clk), .done_tb(d2), .tests(t2), .errors(e2));
    ctl_case #(.N(4), .SEED(32'h1004)) u_n4 (.clk(clk), .done_tb(d4), .tests(t4), .errors(e4));

    initial begin
        $dumpfile("sim/controller_tb.vcd");
        $dumpvars(0, controller_tb);
    end

    initial begin
        repeat (200000) @(posedge clk);
        $display("FAIL watchdog timeout");
        $display("CONTROLLER TEST RESULT: FAIL");
        $display("Tests: %0d", t1 + t2 + t4);
        $display("Errors: %0d", e1 + e2 + e4 + 1);
        $finish;
    end

    initial begin
        int t, e;
        wait (d1 && d2 && d4);
        @(posedge clk); #1;
        t = t1 + t2 + t4;
        e = e1 + e2 + e4;
        $display("========================================");
        if (e == 0 && t > 0) $display("CONTROLLER TEST RESULT: PASS");
        else                 $display("CONTROLLER TEST RESULT: FAIL");
        $display("Tests: %0d", t);
        $display("Errors: %0d", e);
        $display("========================================");
        $finish;
    end
endmodule
