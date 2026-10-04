`timescale 1ns/1ps

module controller_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst1, start1;
    wire accept1, clear1, compute1, capture1, busy1, done1;
    wire [0:0] step1;
    reg rst2, start2;
    wire accept2, clear2, compute2, capture2, busy2, done2;
    wire [1:0] step2;
    reg rst4, start4;
    wire accept4, clear4, compute4, capture4, busy4, done4;
    wire [3:0] step4;

    integer tests = 0;
    integer errors = 0;
    integer cycles = 0;
    reg finished = 1'b0;

    controller #(.ARRAY_SIZE(1)) dut1 (
        .clk(clk), .rst_n(rst1), .start(start1), .accept(accept1),
        .clear(clear1), .compute(compute1), .capture(capture1),
        .busy(busy1), .done(done1), .step(step1)
    );
    controller #(.ARRAY_SIZE(2)) dut2 (
        .clk(clk), .rst_n(rst2), .start(start2), .accept(accept2),
        .clear(clear2), .compute(compute2), .capture(capture2),
        .busy(busy2), .done(done2), .step(step2)
    );
    controller #(.ARRAY_SIZE(4)) dut4 (
        .clk(clk), .rst_n(rst4), .start(start4), .accept(accept4),
        .clear(clear4), .compute(compute4), .capture(capture4),
        .busy(busy4), .done(done4), .step(step4)
    );

    task automatic check1;
        input integer ea, ecl, eco, ecap, eb, ed, es;
        begin
            tests = tests + 1;
            if ({accept1,clear1,compute1,capture1,busy1,done1} !==
                {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
                errors = errors + 1;
                $display("CTRL N1 phase mismatch exp=%b%b%b%b%b%b got=%b%b%b%b%b%b",
                         ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0],
                         accept1,clear1,compute1,capture1,busy1,done1);
            end
            tests = tests + 1;
            if (step1 !== es[0:0]) begin
                errors = errors + 1; $display("CTRL N1 step expected=%0d got=%0d", es, step1);
            end
        end
    endtask

    task automatic check2;
        input integer ea, ecl, eco, ecap, eb, ed, es;
        begin
            tests = tests + 1;
            if ({accept2,clear2,compute2,capture2,busy2,done2} !==
                {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
                errors = errors + 1;
                $display("CTRL N2 phase mismatch step=%0d", step2);
            end
            tests = tests + 1;
            if (step2 !== es[1:0]) begin
                errors = errors + 1; $display("CTRL N2 step expected=%0d got=%0d", es, step2);
            end
        end
    endtask

    task automatic check4;
        input integer ea, ecl, eco, ecap, eb, ed, es;
        begin
            tests = tests + 1;
            if ({accept4,clear4,compute4,capture4,busy4,done4} !==
                {ea[0],ecl[0],eco[0],ecap[0],eb[0],ed[0]}) begin
                errors = errors + 1;
                $display("CTRL N4 phase mismatch step=%0d exp a/cl/co/cap/b/d=%0d%0d%0d%0d%0d%0d got=%b%b%b%b%b%b",
                         step4, ea,ecl,eco,ecap,eb,ed,
                         accept4,clear4,compute4,capture4,busy4,done4);
            end
            tests = tests + 1;
            if (step4 !== es[3:0]) begin
                errors = errors + 1; $display("CTRL N4 step expected=%0d got=%0d", es, step4);
            end
            tests = tests + 1;
            if ((clear4 && compute4) || (clear4 && capture4) || (compute4 && capture4)) begin
                errors = errors + 1; $display("CTRL N4 overlapping controls");
            end
        end
    endtask

    task automatic transaction1;
        integer compute_edges;
        begin
            compute_edges = 0;
            @(negedge clk); start1 = 1; #1; check1(1,0,0,0,0,0,0);
            @(posedge clk); #1; check1(0,1,0,0,1,0,0);
            @(negedge clk); start1 = 0;
            @(posedge clk); #1; check1(0,0,1,0,1,0,0);
            if (compute1) compute_edges = compute_edges + 1;
            @(posedge clk); #1; check1(0,0,0,1,1,0,0);
            @(posedge clk); #1; check1(0,0,0,0,0,1,0);
            @(posedge clk); #1; check1(0,0,0,0,0,0,0);
            tests = tests + 1;
            if (compute_edges !== 1) begin errors = errors + 1; $display("CTRL N1 compute count=%0d", compute_edges); end
        end
    endtask

    task automatic transaction2;
        integer t;
        integer compute_edges;
        begin
            compute_edges = 0;
            @(negedge clk); start2 = 1; #1; check2(1,0,0,0,0,0,0);
            @(posedge clk); #1; check2(0,1,0,0,1,0,0);
            @(negedge clk); start2 = 0;
            @(posedge clk); #1; check2(0,0,1,0,1,0,0);
            for (t = 0; t < 4; t = t + 1) begin
                if (compute2) compute_edges = compute_edges + 1;
                @(posedge clk); #1;
                if (t < 3) check2(0,0,1,0,1,0,t+1);
                else check2(0,0,0,1,1,0,3);
            end
            @(posedge clk); #1; check2(0,0,0,0,0,1,0);
            @(posedge clk); #1; check2(0,0,0,0,0,0,0);
            tests = tests + 1;
            if (compute_edges !== 4) begin errors = errors + 1; $display("CTRL N2 compute count=%0d", compute_edges); end
        end
    endtask

    task automatic transaction4;
        input integer inject_busy_start;
        integer t;
        integer compute_edges;
        begin
            compute_edges = 0;
            @(negedge clk); start4 = 1; #1; check4(1,0,0,0,0,0,0);
            @(posedge clk); #1; check4(0,1,0,0,1,0,0);
            @(negedge clk); start4 = 0;
            @(posedge clk); #1; check4(0,0,1,0,1,0,0);
            for (t = 0; t < 10; t = t + 1) begin
                if (compute4) compute_edges = compute_edges + 1;
                if (inject_busy_start && (t == 3)) begin
                    @(negedge clk); start4 = 1; #1; check4(0,0,1,0,1,0,t);
                end
                @(posedge clk); #1;
                if (inject_busy_start && (t == 3)) begin
                    @(negedge clk); start4 = 0;
                    if (t < 9) check4(0,0,1,0,1,0,t+1);
                end else if (t < 9) check4(0,0,1,0,1,0,t+1);
                else check4(0,0,0,1,1,0,9);
            end
            @(posedge clk); #1; check4(0,0,0,0,0,1,0);
            @(posedge clk); #1; check4(0,0,0,0,0,0,0);
            tests = tests + 1;
            if (compute_edges !== 10) begin errors = errors + 1; $display("CTRL N4 compute count=%0d", compute_edges); end
        end
    endtask

    task automatic summary;
        begin
            if ((errors == 0) && (tests > 0)) $display("CONTROLLER TEST RESULT: PASS");
            else $display("CONTROLLER TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if ((cycles > 2000) && !finished) begin
            errors = errors + 1; finished = 1'b1;
            $display("Watchdog timeout"); summary(); $finish;
        end
    end

    initial begin
        rst1 = 0; start1 = 0; rst2 = 0; start2 = 0; rst4 = 0; start4 = 0;
        @(posedge clk); #1;
        check1(0,0,0,0,0,0,0); check2(0,0,0,0,0,0,0); check4(0,0,0,0,0,0,0);
        @(negedge clk); rst1 = 1; rst2 = 1; rst4 = 1;

        transaction1();
        transaction2();
        transaction4(1);
        transaction4(0);

        @(negedge clk); start4 = 1;
        @(posedge clk); #1; check4(0,1,0,0,1,0,0);
        @(negedge clk); start4 = 0;
        @(posedge clk); #1; check4(0,0,1,0,1,0,0);
        @(negedge clk); rst4 = 0;
        @(posedge clk); #1; check4(0,0,0,0,0,0,0);
        @(negedge clk); rst4 = 1;
        @(posedge clk); #1; check4(0,0,0,0,0,0,0);

        finished = 1'b1;
        summary();
        $finish;
    end
endmodule
