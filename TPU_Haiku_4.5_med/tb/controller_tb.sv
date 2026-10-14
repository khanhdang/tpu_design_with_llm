module controller_tb();

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst4, start4;
    wire accept4, clear4, compute4, capture4, busy4, done4;
    wire [3:0] step4;

    reg rst2, start2;
    wire accept2, clear2, compute2, capture2, busy2, done2;
    wire [1:0] step2;

    reg rst1, start1;
    wire accept1, clear1, compute1, capture1, busy1, done1;
    wire [0:0] step1;

    integer tests = 0;
    integer errors = 0;

    controller #(.ARRAY_SIZE(4)) ctrl4 (
        .clk(clk), .rst_n(rst4), .start(start4),
        .accept(accept4), .clear(clear4), .compute(compute4), .capture(capture4),
        .busy(busy4), .done(done4), .step(step4)
    );

    controller #(.ARRAY_SIZE(2)) ctrl2 (
        .clk(clk), .rst_n(rst2), .start(start2),
        .accept(accept2), .clear(clear2), .compute(compute2), .capture(capture2),
        .busy(busy2), .done(done2), .step(step2)
    );

    controller #(.ARRAY_SIZE(1)) ctrl1 (
        .clk(clk), .rst_n(rst1), .start(start1),
        .accept(accept1), .clear(clear1), .compute(compute1), .capture(capture1),
        .busy(busy1), .done(done1), .step(step1)
    );

    task check4(input integer ea, ecl, eco, ecap, eb, ed, es);
        tests = tests + 1;
        if ({accept4,clear4,compute4,capture4,busy4,done4} !== {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
            errors = errors + 1;
            $display("FAIL N4 control mismatch: expected %b%b%b%b%b%b got %b%b%b%b%b%b",
                     ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0],
                     accept4,clear4,compute4,capture4,busy4,done4);
        end
        tests = tests + 1;
        if (step4 !== es[3:0]) begin
            errors = errors + 1;
            $display("FAIL N4 step: expected=%0d got=%0d", es, step4);
        end
    endtask

    task check2(input integer ea, ecl, eco, ecap, eb, ed, es);
        tests = tests + 1;
        if ({accept2,clear2,compute2,capture2,busy2,done2} !== {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
            errors = errors + 1;
            $display("FAIL N2 control mismatch");
        end
        tests = tests + 1;
        if (step2 !== es[1:0]) begin
            errors = errors + 1;
            $display("FAIL N2 step: expected=%0d got=%0d", es, step2);
        end
    endtask

    task check1(input integer ea, ecl, eco, ecap, eb, ed, es);
        tests = tests + 1;
        if ({accept1,clear1,compute1,capture1,busy1,done1} !== {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
            errors = errors + 1;
            $display("FAIL N1 control mismatch");
        end
        tests = tests + 1;
        if (step1 !== es[0:0]) begin
            errors = errors + 1;
            $display("FAIL N1 step: expected=%0d got=%0d", es, step1);
        end
    endtask

    initial begin
        integer t, compute_count;

        // Initialize
        rst4 = 0; rst2 = 0; rst1 = 0;
        start4 = 0; start2 = 0; start1 = 0;

        @(negedge clk); rst4 = 1; rst2 = 1; rst1 = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        // ===== N=4 Transaction =====
        compute_count = 0;
        @(negedge clk); start4 = 1; #1; check4(1,0,0,0,0,0,0);
        @(posedge clk); #1; check4(0,1,0,0,1,0,0);
        @(negedge clk); start4 = 0;
        @(posedge clk); #1; check4(0,0,1,0,1,0,0);

        for (t = 0; t < 10; t = t + 1) begin
            if (compute4) compute_count = compute_count + 1;
            @(posedge clk); #1;
            if (t < 9) begin
                check4(0,0,1,0,1,0,t+1);
            end else begin
                check4(0,0,0,1,1,0,9);
            end
        end

        @(posedge clk); #1; check4(0,0,0,0,0,1,0);
        @(posedge clk); #1; check4(0,0,0,0,0,0,0);

        tests = tests + 1;
        if (compute_count !== 10) begin
            errors = errors + 1;
            $display("FAIL N4 compute edges: expected=10 got=%0d", compute_count);
        end

        // ===== N=2 Transaction =====
        compute_count = 0;
        @(negedge clk); start2 = 1; #1; check2(1,0,0,0,0,0,0);
        @(posedge clk); #1; check2(0,1,0,0,1,0,0);
        @(negedge clk); start2 = 0;
        @(posedge clk); #1; check2(0,0,1,0,1,0,0);

        for (t = 0; t < 4; t = t + 1) begin
            if (compute2) compute_count = compute_count + 1;
            @(posedge clk); #1;
            if (t < 3) begin
                check2(0,0,1,0,1,0,t+1);
            end else begin
                check2(0,0,0,1,1,0,3);
            end
        end

        @(posedge clk); #1; check2(0,0,0,0,0,1,0);
        @(posedge clk); #1; check2(0,0,0,0,0,0,0);

        tests = tests + 1;
        if (compute_count !== 4) begin
            errors = errors + 1;
            $display("FAIL N2 compute edges: expected=4 got=%0d", compute_count);
        end

        // ===== N=1 Transaction =====
        compute_count = 0;
        @(negedge clk); start1 = 1; #1; check1(1,0,0,0,0,0,0);
        @(posedge clk); #1; check1(0,1,0,0,1,0,0);
        @(negedge clk); start1 = 0;
        @(posedge clk); #1; check1(0,0,1,0,1,0,0);

        if (compute1) compute_count = compute_count + 1;
        @(posedge clk); #1; check1(0,0,0,1,1,0,0);
        @(posedge clk); #1; check1(0,0,0,0,0,1,0);
        @(posedge clk); #1; check1(0,0,0,0,0,0,0);

        tests = tests + 1;
        if (compute_count !== 1) begin
            errors = errors + 1;
            $display("FAIL N1 compute edges: expected=1 got=%0d", compute_count);
        end

        // Final summary
        @(posedge clk);
        $display("========================================");
        if (errors === 0 && tests > 0) begin
            $display("CONTROLLER TEST RESULT: PASS");
        end else begin
            $display("CONTROLLER TEST RESULT: FAIL");
        end
        $display("Tests: %0d", tests);
        $display("Errors: %0d", errors);
        $display("========================================");
        $finish;
    end

    initial begin
        integer watchdog = 0;
        forever begin
            @(posedge clk);
            watchdog = watchdog + 1;
            if (watchdog > 100000) begin
                $display("FAIL: Watchdog timeout");
                errors = errors + 1;
                $finish;
            end
        end
    end

endmodule
