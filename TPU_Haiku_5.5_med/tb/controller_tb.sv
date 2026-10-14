// Self-checking testbench for controller.
// Checks control behavior only (no matrix data). Each harness instance drives
// one controller and compares every cycle against an independent reference
// state machine that is updated from the TB-driven rst_n and start values.
// Instances: N=1, N=2, N=4. Compute-edge counts must equal 3*N-2 (1, 4, 10).

// One controller plus its stimulus, reference FSM, and checker.
module ctrl_harness #(
    parameter int N = 4
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);
    localparam int STEP_W     = ($clog2(3*N-2) > 1) ? $clog2(3*N-2) : 1;
    localparam int STEP_LAST  = 3*N - 3;
    localparam int TXN_COMPUTE = 3*N - 2;
    localparam int TIMEOUT    = 3*N + 8;   // cycles allowed for one transaction

    // Reference FSM encoding, independent of the DUT's encoding.
    localparam int R_IDLE    = 0;
    localparam int R_CLEAR   = 1;
    localparam int R_RUN     = 2;
    localparam int R_CAPTURE = 3;

    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic accept;
    logic clear;
    logic compute;
    logic capture;
    logic busy;
    logic done;
    logic [STEP_W-1:0] step;

    controller #(.ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .accept(accept), .clear(clear), .compute(compute), .capture(capture),
        .busy(busy), .done(done), .step(step)
    );

    integer ref_state = R_IDLE;
    integer ref_step  = 0;
    logic   ref_done  = 1'b0;
    integer ref_txn   = 0;     // reference compute edges in the current transaction
    integer dut_txn   = 0;     // DUT compute edges observed in the current transaction
    integer txns_done = 0;     // reference completed transactions
    integer done_seen = 0;     // DUT cycles with done high
    integer cycles    = 0;

    // Compare one signal against its reference value.
    task automatic chk(input logic got, input logic exp, input string name);
        begin
            tests++;
            if (got !== exp) begin
                errors++;
                $display("FAIL CTRL N=%0d %s: expected=%0b got=%0b (ref_state=%0d ref_step=%0d rst_n=%0b start=%0b)",
                         N, name, exp, got, ref_state, ref_step, rst_n, start);
            end
        end
    endtask

    // Check every decoded output for the upcoming edge against the reference.
    task automatic check_outputs();
        logic exp_accept;
        begin
            exp_accept = (ref_state == R_IDLE) && start;
            chk(accept,  exp_accept,                   "accept");
            chk(busy,    ref_state != R_IDLE,          "busy");
            chk(clear,   ref_state == R_CLEAR,         "clear");
            chk(compute, ref_state == R_RUN,           "compute");
            chk(capture, ref_state == R_CAPTURE,       "capture");
            chk(done,    ref_done,                     "done");
            if (ref_state == R_RUN) begin
                tests++;
                if (step !== STEP_W'(ref_step)) begin
                    errors++;
                    $display("FAIL CTRL N=%0d step: expected=%0d got=%0d (ref_state=%0d)",
                             N, ref_step, step, ref_state);
                end
            end
        end
    endtask

    // Advance the reference FSM across one rising edge using the driven inputs.
    task automatic update_ref(input logic rstn, input logic st);
        begin
            if (!rstn) begin
                ref_state = R_IDLE;
                ref_step  = 0;
                ref_done  = 1'b0;
            end else begin
                ref_done = 1'b0;
                case (ref_state)
                    R_IDLE: begin
                        if (st) begin
                            ref_state = R_CLEAR;
                            ref_txn   = 0;
                            dut_txn   = 0;
                        end
                    end
                    R_CLEAR: begin
                        ref_state = R_RUN;
                        ref_step  = 0;
                    end
                    R_RUN: begin
                        ref_txn++;
                        if (ref_step == STEP_LAST)
                            ref_state = R_CAPTURE;
                        else
                            ref_step++;
                    end
                    R_CAPTURE: begin
                        ref_state = R_IDLE;
                        ref_step  = 0;
                        ref_done  = 1'b1;
                        txns_done++;
                        tests++;
                        if (ref_txn !== TXN_COMPUTE || dut_txn !== TXN_COMPUTE) begin
                            errors++;
                            $display("FAIL CTRL N=%0d compute edges: expected=%0d ref=%0d dut=%0d",
                                     N, TXN_COMPUTE, ref_txn, dut_txn);
                        end
                    end
                    default: ref_state = R_IDLE;
                endcase
            end
        end
    endtask

    // One clock cycle: drive at negedge, check the decode, then advance the reference.
    // start is forced low during reset so the reset edge cannot accept a request.
    task automatic tick(input logic rstn, input logic st);
        begin
            @(negedge clk);
            rst_n = rstn;
            start = rstn ? st : 1'b0;
            #1;
            if (rstn) begin
                check_outputs();
                if (done === 1'b1)
                    done_seen++;
                if (compute === 1'b1)
                    dut_txn++;
            end
            @(posedge clk);
            update_ref(rstn, start);
            #1;
            if (!rstn)
                check_outputs();
            cycles++;
        end
    endtask

    // Run one full transaction from an accepted request, with timeout.
    task automatic run_one();
        integer k;
        begin
            tick(1'b1, 1'b1);
            for (k = 0; k < TIMEOUT && ref_state != R_IDLE; k++)
                tick(1'b1, 1'b0);
            if (ref_state != R_IDLE) begin
                errors++;
                $display("FAIL CTRL N=%0d timeout: transaction did not finish in %0d cycles",
                         N, TIMEOUT);
            end
        end
    endtask

    // Keep start high for the whole transaction; requests during busy are ignored.
    task automatic ignored_while_busy();
        integer k;
        begin
            tick(1'b1, 1'b1);
            for (k = 0; k < TIMEOUT && ref_state != R_IDLE; k++)
                tick(1'b1, 1'b1);
            if (ref_state != R_IDLE) begin
                errors++;
                $display("FAIL CTRL N=%0d timeout: busy request run did not finish", N);
            end
        end
    endtask

    // Drive start high continuously across two transactions: the second is
    // accepted on the first idle edge after the first completes.
    task automatic back_to_back();
        integer k;
        integer target;
        begin
            target = txns_done + 2;
            for (k = 0; k < 2 * TIMEOUT && txns_done < target; k++)
                tick(1'b1, 1'b1);
            if (txns_done < target) begin
                errors++;
                $display("FAIL CTRL N=%0d timeout: back-to-back requests did not complete", N);
            end
            tick(1'b1, 1'b0);
            for (k = 0; k < TIMEOUT && ref_state != R_IDLE; k++)
                tick(1'b1, 1'b0);
        end
    endtask

    // Reset in the middle of a transaction phase; the following idle must be clean.
    task automatic reset_during(input integer phase, input integer step_at);
        integer k;
        begin
            tick(1'b1, 1'b1);
            for (k = 0; k < TIMEOUT && ref_state != phase; k++)
                tick(1'b1, 1'b0);
            for (k = 0; k < TIMEOUT && ref_state == R_RUN && ref_step < step_at; k++)
                tick(1'b1, 1'b0);
            tick(1'b0, 1'b1);     // reset with start high: must be ignored
            tick(1'b1, 1'b0);
            tick(1'b1, 1'b0);
        end
    endtask

    initial begin
        integer p;
        finished = 1'b0;
        tests    = 0;
        errors   = 0;

        // Synchronous active-low reset, then idle with no requests.
        tick(1'b0, 1'b0);
        tick(1'b0, 1'b0);
        for (p = 0; p < 3; p++)
            tick(1'b1, 1'b0);

        // One accepted request; done must pulse for exactly one cycle.
        run_one();
        tick(1'b1, 1'b0);
        tick(1'b1, 1'b0);

        // Requests while busy are ignored.
        ignored_while_busy();
        tick(1'b1, 1'b0);

        // Start held high across completion: back-to-back transactions.
        back_to_back();
        tick(1'b1, 1'b0);

        // Consecutive transactions with and without idle gaps.
        for (p = 0; p < 3; p++) begin
            run_one();
            for (int g = 0; g < p; g++)
                tick(1'b1, 1'b0);
        end

        // Reset during RUN (mid-step), CLEAR, and CAPTURE; then recover.
        reset_during(R_RUN, STEP_LAST);
        run_one();
        reset_during(R_CLEAR, 0);
        run_one();
        reset_during(R_CAPTURE, 0);
        run_one();

        // Idle cycle so the last transaction's done pulse is sampled, then count pulses.
        tick(1'b1, 1'b0);
        tests++;
        if (done_seen !== txns_done) begin
            errors++;
            $display("FAIL CTRL N=%0d done pulses: expected=%0d seen=%0d",
                     N, txns_done, done_seen);
        end

        finished = 1'b1;
    end
endmodule

module controller_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    integer t_n1, e_n1, t_n2, e_n2, t_n4, e_n4;
    logic   f_n1, f_n2, f_n4;

    ctrl_harness #(.N(1)) h_n1 (.clk(clk), .tests(t_n1), .errors(e_n1), .finished(f_n1));
    ctrl_harness #(.N(2)) h_n2 (.clk(clk), .tests(t_n2), .errors(e_n2), .finished(f_n2));
    ctrl_harness #(.N(4)) h_n4 (.clk(clk), .tests(t_n4), .errors(e_n4), .finished(f_n4));

    integer tests;
    integer errors;
    bit     finished = 1'b0;

    task automatic print_summary;
        begin
            tests  = t_n1 + t_n2 + t_n4;
            errors = e_n1 + e_n2 + e_n4;
            if (errors == 0 && tests > 0)
                $display("CONTROLLER TEST RESULT: PASS");
            else
                $display("CONTROLLER TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    // Watchdog: bounded run time; reports FAIL if the harnesses never finish.
    initial begin
        #2000000;
        if (!finished) begin
            finished = 1'b1;
            $display("FAIL CONTROLLER watchdog timeout");
            tests  = t_n1 + t_n2 + t_n4;
            errors = e_n1 + e_n2 + e_n4 + 1;
            $display("CONTROLLER TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $finish;
        end
    end

    initial begin
        $dumpfile("sim/controller_tb.vcd");
        $dumpvars(0, controller_tb);
        wait (f_n1 && f_n2 && f_n4);
        #1;
        finished = 1'b1;
        print_summary();
        $finish;
    end
endmodule
