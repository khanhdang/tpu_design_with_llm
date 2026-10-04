`timescale 1ns/1ps

module systolic_array_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst4, clr4, en4;
    reg [31:0] left4, top4;
    wire [511:0] c4;

    reg rst2, clr2, en2;
    reg [7:0] left2, top2;
    wire [63:0] c2;

    reg rst1, clr1, en1;
    reg [7:0] left1, top1;
    wire [15:0] c1;

    integer signed a4 [0:3][0:3];
    integer signed b4 [0:3][0:3];
    integer signed expected4 [0:3][0:3];
    integer signed a2 [0:1][0:1];
    integer signed b2 [0:1][0:1];
    integer signed expected2 [0:1][0:1];

    integer tests = 0;
    integer errors = 0;
    integer cycles = 0;
    integer seed = 32'h31415927;
    reg finished = 1'b0;

    systolic_array #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4)) dut4 (
        .clk(clk), .rst_n(rst4), .clr(clr4), .en(en4),
        .a_left(left4), .b_top(top4), .c(c4)
    );

    systolic_array #(.DATA_WIDTH(4), .ACC_WIDTH(16), .ARRAY_SIZE(2)) dut2 (
        .clk(clk), .rst_n(rst2), .clr(clr2), .en(en2),
        .a_left(left2), .b_top(top2), .c(c2)
    );

    systolic_array #(.DATA_WIDTH(8), .ACC_WIDTH(16), .ARRAY_SIZE(1)) dut1 (
        .clk(clk), .rst_n(rst1), .clr(clr1), .en(en1),
        .a_left(left1), .b_top(top1), .c(c1)
    );

    task automatic check_zero4;
        integer x;
        begin
            for (x = 0; x < 16; x = x + 1) begin
                tests = tests + 1;
                if (c4[x*32 +: 32] !== 32'sd0) begin
                    errors = errors + 1;
                    $display("ARRAY N4 clear/reset mismatch element=%0d got=%0d", x,
                             $signed(c4[x*32 +: 32]));
                end
            end
        end
    endtask

    task automatic run_matrix4;
        input integer case_id;
        input integer use_stall;
        integer i, j, k, t;
        reg [511:0] stall_snapshot;
        begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    expected4[i][j] = 0;
                    for (k = 0; k < 4; k = k + 1)
                        expected4[i][j] = expected4[i][j] + a4[i][k] * b4[k][j];
                end

            @(negedge clk); rst4 = 1; clr4 = 1; en4 = 1; left4 = '1; top4 = '1;
            @(posedge clk); #1; check_zero4();
            @(negedge clk); clr4 = 0; en4 = 1;

            for (t = 0; t <= 9; t = t + 1) begin
                if (use_stall && (t == 3)) begin
                    stall_snapshot = c4;
                    left4 = 32'h7f7f7f7f; top4 = 32'h80808080; en4 = 0;
                    @(posedge clk); #1;
                    tests = tests + 1;
                    if (c4 !== stall_snapshot) begin
                        errors = errors + 1;
                        $display("ARRAY N4 enable stall changed accumulators case=%0d", case_id);
                    end
                    @(negedge clk); en4 = 1;
                end
                left4 = 0; top4 = 0;
                for (i = 0; i < 4; i = i + 1) begin
                    k = t - i;
                    if ((k >= 0) && (k < 4)) left4[i*8 +: 8] = a4[i][k];
                end
                for (j = 0; j < 4; j = j + 1) begin
                    k = t - j;
                    if ((k >= 0) && (k < 4)) top4[j*8 +: 8] = b4[k][j];
                end
                @(posedge clk); #1;
                if (t != 9) @(negedge clk);
            end

            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    tests = tests + 1;
                    if (c4[(i*4+j)*32 +: 32] !== expected4[i][j][31:0]) begin
                        errors = errors + 1;
                        $display("ARRAY N4 case=%0d C[%0d][%0d] expected=%0d got=%0d",
                                 case_id, i, j, expected4[i][j],
                                 $signed(c4[(i*4+j)*32 +: 32]));
                    end
                end
        end
    endtask

    task automatic run_matrix2;
        input integer case_id;
        integer i, j, k, t;
        begin
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    expected2[i][j] = 0;
                    for (k = 0; k < 2; k = k + 1)
                        expected2[i][j] = expected2[i][j] + a2[i][k] * b2[k][j];
                end
            @(negedge clk); rst2 = 1; clr2 = 1; en2 = 1; left2 = '1; top2 = '1;
            @(posedge clk); #1;
            for (i = 0; i < 4; i = i + 1) begin
                tests = tests + 1;
                if (c2[i*16 +: 16] !== 16'sd0) begin
                    errors = errors + 1;
                    $display("ARRAY N2 clear mismatch element=%0d", i);
                end
            end
            @(negedge clk); clr2 = 0; en2 = 1;
            for (t = 0; t <= 3; t = t + 1) begin
                left2 = 0; top2 = 0;
                for (i = 0; i < 2; i = i + 1) begin
                    k = t-i;
                    if ((k >= 0) && (k < 2)) left2[i*4 +: 4] = a2[i][k];
                end
                for (j = 0; j < 2; j = j + 1) begin
                    k = t-j;
                    if ((k >= 0) && (k < 2)) top2[j*4 +: 4] = b2[k][j];
                end
                @(posedge clk); #1;
                if (t != 3) @(negedge clk);
            end
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    tests = tests + 1;
                    if (c2[(i*2+j)*16 +: 16] !== expected2[i][j][15:0]) begin
                        errors = errors + 1;
                        $display("ARRAY N2 case=%0d C[%0d][%0d] expected=%0d got=%0d",
                                 case_id, i, j, expected2[i][j],
                                 $signed(c2[(i*2+j)*16 +: 16]));
                    end
                end
        end
    endtask

    task automatic run_value1;
        input integer av;
        input integer bv;
        reg signed [15:0] expected;
        begin
            expected = av * bv;
            @(negedge clk); rst1 = 1; clr1 = 1; en1 = 1; left1 = '1; top1 = '1;
            @(posedge clk); #1;
            tests = tests + 1;
            if (c1 !== 16'sd0) begin errors = errors + 1; $display("ARRAY N1 clear mismatch"); end
            @(negedge clk); clr1 = 0; en1 = 1; left1 = av; top1 = bv;
            @(posedge clk); #1;
            tests = tests + 1;
            if (c1 !== expected) begin
                errors = errors + 1;
                $display("ARRAY N1 expected=%0d got=%0d", expected, $signed(c1));
            end
        end
    endtask

    task automatic summary;
        begin
            if ((errors == 0) && (tests > 0)) $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
            else $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if ((cycles > 10000) && !finished) begin
            errors = errors + 1; finished = 1'b1;
            $display("Watchdog timeout seed=%0d", seed); summary(); $finish;
        end
    end

    integer i, j, n;
    initial begin
        rst4 = 0; clr4 = 0; en4 = 0; left4 = 0; top4 = 0;
        rst2 = 0; clr2 = 0; en2 = 0; left2 = 0; top2 = 0;
        rst1 = 0; clr1 = 0; en1 = 0; left1 = 0; top1 = 0;
        @(negedge clk); rst4 = 0; rst2 = 0; rst1 = 0;
        @(posedge clk); #1; check_zero4();

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin a4[i][j] = 0; b4[i][j] = 0; end
        run_matrix4(0, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = (i == j); b4[i][j] = (i == j) ? (i+2) : 0;
            end
        run_matrix4(1, 1);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = i*4+j+1; b4[i][j] = (i+j)%5+1;
            end
        run_matrix4(2, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = -(i+j+1); b4[i][j] = j-i-2;
            end
        run_matrix4(3, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = ((i+j)&1) ? -128 : 127;
                b4[i][j] = ((i*4+j)&1) ? 127 : -128;
            end
        run_matrix4(4, 0);

        for (n = 0; n < 20; n = n + 1) begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    seed = seed * 1103515245 + 12345; a4[i][j] = $signed(seed[7:0]);
                    seed = seed * 1103515245 + 12345; b4[i][j] = $signed(seed[7:0]);
                end
            run_matrix4(100+n, (n == 7));
        end

        a2[0][0] = 7;  a2[0][1] = -8; a2[1][0] = -3; a2[1][1] = 5;
        b2[0][0] = -8; b2[0][1] = 2; b2[1][0] = 7;  b2[1][1] = -4;
        run_matrix2(0);

        @(negedge clk); clr2 = 0; en2 = 1; left2 = 8'h77; top2 = 8'h88;
        @(posedge clk); @(negedge clk); rst2 = 0;
        @(posedge clk); #1;
        for (i = 0; i < 4; i = i + 1) begin
            tests = tests + 1;
            if (c2[i*16 +: 16] !== 0) begin
                errors = errors + 1; $display("ARRAY N2 synchronous reset mismatch element=%0d", i);
            end
        end

        run_value1(-128, 127);
        run_value1(-128, -128);

        finished = 1'b1;
        summary();
        $finish;
    end
endmodule
