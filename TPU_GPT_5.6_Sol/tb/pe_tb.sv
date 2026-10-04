`timescale 1ns/1ps

module pe_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst8, clr8, en8;
    reg signed [7:0] ai8, bi8;
    wire signed [7:0] ao8, bo8;
    wire signed [31:0] acc8;

    reg rst4, clr4, en4;
    reg signed [3:0] ai4, bi4;
    wire signed [3:0] ao4, bo4;
    wire signed [11:0] acc4;

    reg signed [7:0] ref_ao8 = 0, ref_bo8 = 0;
    reg signed [31:0] ref_acc8 = 0;
    reg signed [3:0] ref_ao4 = 0, ref_bo4 = 0;
    reg signed [11:0] ref_acc4 = 0;
    integer tests = 0;
    integer errors = 0;
    integer cycles = 0;
    integer seed = 32'h2468ace1;
    reg finished = 1'b0;

    pe #(.DATA_WIDTH(8), .ACC_WIDTH(32)) dut8 (
        .clk(clk), .rst_n(rst8), .clr(clr8), .en(en8),
        .a_in(ai8), .b_in(bi8), .a_out(ao8), .b_out(bo8), .acc(acc8)
    );

    pe #(.DATA_WIDTH(4), .ACC_WIDTH(12)) dut4 (
        .clk(clk), .rst_n(rst4), .clr(clr4), .en(en4),
        .a_in(ai4), .b_in(bi4), .a_out(ao4), .b_out(bo4), .acc(acc4)
    );

    task automatic compare8;
        begin
            tests = tests + 1;
            if (ao8 !== ref_ao8) begin
                errors = errors + 1;
                $display("PE8 a_out mismatch expected=%0d got=%0d", ref_ao8, ao8);
            end
            tests = tests + 1;
            if (bo8 !== ref_bo8) begin
                errors = errors + 1;
                $display("PE8 b_out mismatch expected=%0d got=%0d", ref_bo8, bo8);
            end
            tests = tests + 1;
            if (acc8 !== ref_acc8) begin
                errors = errors + 1;
                $display("PE8 acc mismatch expected=%0d got=%0d", ref_acc8, acc8);
            end
        end
    endtask

    task automatic step8;
        input integer r;
        input integer c;
        input integer e;
        input integer av;
        input integer bv;
        reg signed [15:0] product;
        begin
            @(negedge clk);
            rst8 = r; clr8 = c; en8 = e; ai8 = av; bi8 = bv;
            product = $signed(av[7:0]) * $signed(bv[7:0]);
            @(posedge clk); #1;
            if (!r || c) begin
                ref_ao8 = 0; ref_bo8 = 0; ref_acc8 = 0;
            end else if (e) begin
                ref_ao8 = av; ref_bo8 = bv; ref_acc8 = ref_acc8 + product;
            end
            compare8();
        end
    endtask

    task automatic compare4;
        begin
            tests = tests + 1;
            if (ao4 !== ref_ao4) begin
                errors = errors + 1;
                $display("PE4 a_out mismatch expected=%0d got=%0d", ref_ao4, ao4);
            end
            tests = tests + 1;
            if (bo4 !== ref_bo4) begin
                errors = errors + 1;
                $display("PE4 b_out mismatch expected=%0d got=%0d", ref_bo4, bo4);
            end
            tests = tests + 1;
            if (acc4 !== ref_acc4) begin
                errors = errors + 1;
                $display("PE4 acc mismatch expected=%0d got=%0d", ref_acc4, acc4);
            end
        end
    endtask

    task automatic step4;
        input integer r;
        input integer c;
        input integer e;
        input integer av;
        input integer bv;
        reg signed [7:0] product;
        begin
            @(negedge clk);
            rst4 = r; clr4 = c; en4 = e; ai4 = av; bi4 = bv;
            product = $signed(av[3:0]) * $signed(bv[3:0]);
            @(posedge clk); #1;
            if (!r || c) begin
                ref_ao4 = 0; ref_bo4 = 0; ref_acc4 = 0;
            end else if (e) begin
                ref_ao4 = av; ref_bo4 = bv; ref_acc4 = ref_acc4 + product;
            end
            compare4();
        end
    endtask

    task automatic summary;
        begin
            if ((errors == 0) && (tests > 0)) $display("PE TEST RESULT: PASS");
            else $display("PE TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if ((cycles > 1000) && !finished) begin
            errors = errors + 1; finished = 1'b1;
            $display("Watchdog timeout"); summary(); $finish;
        end
    end

    integer i, ra, rb, rc;
    initial begin
        rst8 = 0; clr8 = 0; en8 = 0; ai8 = 0; bi8 = 0;
        rst4 = 0; clr4 = 0; en4 = 0; ai4 = 0; bi4 = 0;

        step8(0, 1, 1, 7, 9);
        step8(1, 1, 0, 0, 0);
        step8(1, 0, 1, 3, -4);
        step8(1, 0, 1, -2, 5);
        step8(1, 0, 1, -128, 127);
        step8(1, 0, 0, 99, 99);
        step8(1, 1, 1, 127, -128);
        step8(1, 0, 1, -128, -128);
        step8(0, 1, 1, 100, 100);
        step8(1, 0, 0, 0, 0);

        step4(0, 0, 1, 3, 3);
        step4(1, 1, 0, 0, 0);
        step4(1, 0, 1, 7, -8);
        step4(1, 0, 1, -8, -8);
        step4(1, 0, 0, 6, 6);
        step4(1, 1, 1, 7, 7);

        for (i = 0; i < 80; i = i + 1) begin
            seed = seed * 1103515245 + 12345; ra = seed;
            seed = seed * 1103515245 + 12345; rb = seed;
            seed = seed * 1103515245 + 12345; rc = seed;
            step8(1, (rc[5:0] == 0), (rc[0] || rc[3]), ra, rb);
        end
        for (i = 0; i < 40; i = i + 1) begin
            seed = seed * 1103515245 + 12345; ra = seed;
            seed = seed * 1103515245 + 12345; rb = seed;
            seed = seed * 1103515245 + 12345; rc = seed;
            step4(1, (rc[4:0] == 0), rc[0], ra, rb);
        end

        finished = 1'b1;
        summary();
        $finish;
    end
endmodule
