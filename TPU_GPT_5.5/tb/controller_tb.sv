module controller_tb;
    logic clk;
    logic rst_n;

    logic start4;
    logic accept4;
    logic clear4;
    logic compute4;
    logic capture4;
    logic busy4;
    logic done4;
    logic [3:0] step4;

    logic start2;
    logic accept2;
    logic clear2;
    logic compute2;
    logic capture2;
    logic busy2;
    logic done2;
    logic [1:0] step2;

    logic start1;
    logic accept1;
    logic clear1;
    logic compute1;
    logic capture1;
    logic busy1;
    logic done1;
    logic [0:0] step1;

    integer tests;
    integer errors;
    logic finished;

    controller #(.ARRAY_SIZE(4)) u_controller4 (
        .clk(clk), .rst_n(rst_n), .start(start4), .accept(accept4),
        .clear(clear4), .compute(compute4), .capture(capture4),
        .busy(busy4), .done(done4), .step(step4)
    );

    controller #(.ARRAY_SIZE(2)) u_controller2 (
        .clk(clk), .rst_n(rst_n), .start(start2), .accept(accept2),
        .clear(clear2), .compute(compute2), .capture(capture2),
        .busy(busy2), .done(done2), .step(step2)
    );

    controller #(.ARRAY_SIZE(1)) u_controller1 (
        .clk(clk), .rst_n(rst_n), .start(start1), .accept(accept1),
        .clear(clear1), .compute(compute1), .capture(capture1),
        .busy(busy1), .done(done1), .step(step1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        repeat (1000) @(posedge clk);
        if (!finished) begin
            errors = errors + 1;
            $display("FAIL watchdog timeout");
            finish_test();
        end
    end

    initial begin
        $dumpfile("sim/controller_tb.vcd");
        $dumpvars(0, controller_tb);
    end

    task automatic expect_bits(
        input [255:0] label,
        input logic got_accept,
        input logic got_clear,
        input logic got_compute,
        input logic got_capture,
        input logic got_busy,
        input logic got_done,
        input integer got_step,
        input logic exp_accept,
        input logic exp_clear,
        input logic exp_compute,
        input logic exp_capture,
        input logic exp_busy,
        input logic exp_done,
        input integer exp_step
    );
        begin
            tests = tests + 1;
            if ((got_accept !== exp_accept) || (got_clear !== exp_clear) ||
                (got_compute !== exp_compute) || (got_capture !== exp_capture) ||
                (got_busy !== exp_busy) || (got_done !== exp_done) ||
                (got_step !== exp_step)) begin
                errors = errors + 1;
                $display("FAIL controller %0s: expected acc=%0b clr=%0b comp=%0b cap=%0b busy=%0b done=%0b step=%0d got acc=%0b clr=%0b comp=%0b cap=%0b busy=%0b done=%0b step=%0d",
                         label, exp_accept, exp_clear, exp_compute, exp_capture,
                         exp_busy, exp_done, exp_step, got_accept, got_clear,
                         got_compute, got_capture, got_busy, got_done, got_step);
            end
        end
    endtask

    task automatic run4(input [255:0] label);
        integer t;
        begin
            @(negedge clk);
            start4 = 1'b1;
            #1;
            expect_bits({label, " idle accept"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " clear"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0);
            @(negedge clk);
            start4 = 1'b0;
            @(posedge clk);
            #1;

            for (t = 0; t <= 9; t = t + 1) begin
                expect_bits({label, " compute"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t);
                @(negedge clk);
                start4 = (t == 3);
                #1;
                if (t == 3) begin
                    expect_bits({label, " ignored busy start"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                                1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t);
                end
                @(posedge clk);
                #1;
                start4 = 1'b0;
            end

            expect_bits({label, " capture"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 9);
            @(posedge clk);
            #1;
            expect_bits({label, " done"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " done pulse ended"}, accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        end
    endtask

    task automatic run2(input [255:0] label);
        integer t;
        begin
            @(negedge clk);
            start2 = 1'b1;
            #1;
            expect_bits({label, " idle accept"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                        1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " clear"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                        1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0);
            @(negedge clk);
            start2 = 1'b0;
            @(posedge clk);
            #1;

            for (t = 0; t <= 3; t = t + 1) begin
                expect_bits({label, " compute"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, t);
                @(posedge clk);
                #1;
            end

            expect_bits({label, " capture"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                        1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 3);
            @(posedge clk);
            #1;
            expect_bits({label, " done"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " done pulse ended"}, accept2, clear2, compute2, capture2, busy2, done2, step2,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        end
    endtask

    task automatic run1(input [255:0] label);
        begin
            @(negedge clk);
            start1 = 1'b1;
            #1;
            expect_bits({label, " idle accept"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " clear"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 0);
            @(negedge clk);
            start1 = 1'b0;
            @(posedge clk);
            #1;
            expect_bits({label, " compute"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " capture"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " done"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 0);
            @(posedge clk);
            #1;
            expect_bits({label, " done pulse ended"}, accept1, clear1, compute1, capture1, busy1, done1, step1,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        end
    endtask

    task automatic reset_abort4;
        begin
            @(negedge clk);
            start4 = 1'b1;
            @(posedge clk);
            #1;
            @(posedge clk);
            #1;
            expect_bits("N4 before reset during run", accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 0);
            @(negedge clk);
            start4 = 1'b0;
            rst_n = 1'b0;
            @(posedge clk);
            #1;
            expect_bits("N4 reset abort", accept4, clear4, compute4, capture4, busy4, done4, step4,
                        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic finish_test;
        begin
            if (!finished) begin
                finished = 1'b1;
                $display("========================================");
                if ((errors == 0) && (tests > 0)) begin
                    $display("CONTROLLER TEST RESULT: PASS");
                end else begin
                    $display("CONTROLLER TEST RESULT: FAIL");
                end
                $display("Tests: %0d", tests);
                $display("Errors: %0d", errors);
                $display("========================================");
                $finish;
            end
        end
    endtask

    initial begin
        tests = 0;
        errors = 0;
        finished = 1'b0;
        rst_n = 1'b1;
        start4 = 1'b0;
        start2 = 1'b0;
        start1 = 1'b0;

        @(negedge clk);
        rst_n = 1'b0;
        start4 = 1'b1;
        start2 = 1'b1;
        start1 = 1'b1;
        @(posedge clk);
        #1;
        expect_bits("global reset N4", accept4, clear4, compute4, capture4, busy4, done4, step4,
                    1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        expect_bits("global reset N2", accept2, clear2, compute2, capture2, busy2, done2, step2,
                    1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        expect_bits("global reset N1", accept1, clear1, compute1, capture1, busy1, done1, step1,
                    1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0);
        @(negedge clk);
        rst_n = 1'b1;
        start4 = 1'b0;
        start2 = 1'b0;
        start1 = 1'b0;

        run1("N1 first transaction");
        run2("N2 first transaction");
        run4("N4 first transaction");
        run4("N4 consecutive transaction");
        reset_abort4();
        run4("N4 after reset abort");

        finish_test();
    end
endmodule
