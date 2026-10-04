module systolic_array_tb;
    logic clk;
    logic rst_n;

    logic clr4;
    logic en4;
    logic [4*8-1:0] a_left4;
    logic [4*8-1:0] b_top4;
    logic [4*4*32-1:0] c4;

    logic clr2;
    logic en2;
    logic [2*8-1:0] a_left2;
    logic [2*8-1:0] b_top2;
    logic [2*2*32-1:0] c2;

    logic clr1;
    logic en1;
    logic [1*4-1:0] a_left1;
    logic [1*4-1:0] b_top1;
    logic [1*1*16-1:0] c1;

    logic signed [7:0] a4 [0:3][0:3];
    logic signed [7:0] b4 [0:3][0:3];
    logic signed [31:0] exp4 [0:3][0:3];
    logic signed [7:0] a2 [0:1][0:1];
    logic signed [7:0] b2 [0:1][0:1];
    logic signed [31:0] exp2 [0:1][0:1];
    logic signed [3:0] a1;
    logic signed [3:0] b1;
    logic signed [15:0] exp1;

    integer tests;
    integer errors;
    integer seed;
    logic finished;

    systolic_array #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4)) u_array4 (
        .clk(clk), .rst_n(rst_n), .clr(clr4), .en(en4),
        .a_left(a_left4), .b_top(b_top4), .c(c4)
    );

    systolic_array #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(2)) u_array2 (
        .clk(clk), .rst_n(rst_n), .clr(clr2), .en(en2),
        .a_left(a_left2), .b_top(b_top2), .c(c2)
    );

    systolic_array #(.DATA_WIDTH(4), .ACC_WIDTH(16), .ARRAY_SIZE(1)) u_array1 (
        .clk(clk), .rst_n(rst_n), .clr(clr1), .en(en1),
        .a_left(a_left1), .b_top(b_top1), .c(c1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        repeat (5000) @(posedge clk);
        if (!finished) begin
            errors = errors + 1;
            $display("FAIL watchdog timeout");
            finish_test();
        end
    end

    initial begin
        $dumpfile("sim/systolic_array_tb.vcd");
        $dumpvars(0, systolic_array_tb);
    end

    task automatic clear4(input [255:0] label);
        integer r;
        integer cidx;
        begin
            @(negedge clk);
            clr4 = 1'b1;
            en4 = 1'b0;
            a_left4 = '0;
            b_top4 = '0;
            @(posedge clk);
            #1;
            clr4 = 1'b0;
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    tests = tests + 1;
                    if ($signed(c4[(r*4+cidx)*32 +: 32]) !== 32'sd0) begin
                        errors = errors + 1;
                        $display("FAIL array4 clear %0s C[%0d][%0d]: got=%0d",
                                 label, r, cidx, $signed(c4[(r*4+cidx)*32 +: 32]));
                    end
                end
            end
        end
    endtask

    task automatic compute4;
        integer r;
        integer cidx;
        integer k;
        integer sum;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    sum = 0;
                    for (k = 0; k < 4; k = k + 1) begin
                        sum = sum + (a4[r][k] * b4[k][cidx]);
                    end
                    exp4[r][cidx] = sum;
                end
            end
        end
    endtask

    task automatic drive_lanes4(input integer t);
        integer i;
        integer idx;
        begin
            a_left4 = '0;
            b_top4 = '0;
            for (i = 0; i < 4; i = i + 1) begin
                idx = t - i;
                if ((idx >= 0) && (idx < 4)) begin
                    a_left4[i*8 +: 8] = a4[i][idx];
                    b_top4[i*8 +: 8] = b4[idx][i];
                end
            end
        end
    endtask

    task automatic compare4(input [255:0] label);
        integer r;
        integer cidx;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    tests = tests + 1;
                    if ($signed(c4[(r*4+cidx)*32 +: 32]) !== exp4[r][cidx]) begin
                        errors = errors + 1;
                        $display("FAIL array4 %0s C[%0d][%0d]: expected=%0d got=%0d",
                                 label, r, cidx, exp4[r][cidx],
                                 $signed(c4[(r*4+cidx)*32 +: 32]));
                    end
                end
            end
        end
    endtask

    task automatic run4(input [255:0] label, input logic stall_mid);
        integer t;
        begin
            compute4();
            clear4(label);
            for (t = 0; t <= 9; t = t + 1) begin
                if (stall_mid && (t == 4)) begin
                    @(negedge clk);
                    en4 = 1'b0;
                    a_left4 = {4{8'h55}};
                    b_top4 = {4{8'haa}};
                    @(posedge clk);
                    #1;
                end

                @(negedge clk);
                clr4 = 1'b0;
                en4 = 1'b1;
                drive_lanes4(t);
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            en4 = 1'b0;
            a_left4 = '0;
            b_top4 = '0;
            #1;
            compare4(label);
        end
    endtask

    task automatic clear2(input [255:0] label);
        integer r;
        integer cidx;
        begin
            @(negedge clk);
            clr2 = 1'b1;
            en2 = 1'b0;
            a_left2 = '0;
            b_top2 = '0;
            @(posedge clk);
            #1;
            clr2 = 1'b0;
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    tests = tests + 1;
                    if ($signed(c2[(r*2+cidx)*32 +: 32]) !== 32'sd0) begin
                        errors = errors + 1;
                        $display("FAIL array2 clear %0s C[%0d][%0d]: got=%0d",
                                 label, r, cidx, $signed(c2[(r*2+cidx)*32 +: 32]));
                    end
                end
            end
        end
    endtask

    task automatic compute2;
        integer r;
        integer cidx;
        integer k;
        integer sum;
        begin
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    sum = 0;
                    for (k = 0; k < 2; k = k + 1) begin
                        sum = sum + (a2[r][k] * b2[k][cidx]);
                    end
                    exp2[r][cidx] = sum;
                end
            end
        end
    endtask

    task automatic drive_lanes2(input integer t);
        integer i;
        integer idx;
        begin
            a_left2 = '0;
            b_top2 = '0;
            for (i = 0; i < 2; i = i + 1) begin
                idx = t - i;
                if ((idx >= 0) && (idx < 2)) begin
                    a_left2[i*8 +: 8] = a2[i][idx];
                    b_top2[i*8 +: 8] = b2[idx][i];
                end
            end
        end
    endtask

    task automatic compare2(input [255:0] label);
        integer r;
        integer cidx;
        begin
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    tests = tests + 1;
                    if ($signed(c2[(r*2+cidx)*32 +: 32]) !== exp2[r][cidx]) begin
                        errors = errors + 1;
                        $display("FAIL array2 %0s C[%0d][%0d]: expected=%0d got=%0d",
                                 label, r, cidx, exp2[r][cidx],
                                 $signed(c2[(r*2+cidx)*32 +: 32]));
                    end
                end
            end
        end
    endtask

    task automatic run2(input [255:0] label);
        integer t;
        begin
            compute2();
            clear2(label);
            for (t = 0; t <= 3; t = t + 1) begin
                @(negedge clk);
                clr2 = 1'b0;
                en2 = 1'b1;
                drive_lanes2(t);
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            en2 = 1'b0;
            a_left2 = '0;
            b_top2 = '0;
            #1;
            compare2(label);
        end
    endtask

    task automatic run1(input logic signed [3:0] aval, input logic signed [3:0] bval, input [255:0] label);
        begin
            a1 = aval;
            b1 = bval;
            exp1 = aval * bval;
            @(negedge clk);
            clr1 = 1'b1;
            en1 = 1'b0;
            a_left1 = '0;
            b_top1 = '0;
            @(posedge clk);
            #1;
            tests = tests + 1;
            if ($signed(c1) !== 16'sd0) begin
                errors = errors + 1;
                $display("FAIL array1 clear %0s: got=%0d", label, $signed(c1));
            end
            @(negedge clk);
            clr1 = 1'b0;
            en1 = 1'b1;
            a_left1 = a1;
            b_top1 = b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            en1 = 1'b0;
            a_left1 = '0;
            b_top1 = '0;
            #1;
            tests = tests + 1;
            if ($signed(c1) !== exp1) begin
                errors = errors + 1;
                $display("FAIL array1 %0s: expected=%0d got=%0d", label, exp1, $signed(c1));
            end
        end
    endtask

    task automatic finish_test;
        begin
            if (!finished) begin
                finished = 1'b1;
                $display("========================================");
                if ((errors == 0) && (tests > 0)) begin
                    $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
                end else begin
                    $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
                end
                $display("Tests: %0d", tests);
                $display("Errors: %0d", errors);
                $display("========================================");
                $finish;
            end
        end
    endtask

    initial begin
        integer r;
        integer cidx;
        integer i;

        tests = 0;
        errors = 0;
        seed = 32'h41525234;
        finished = 1'b0;
        rst_n = 1'b1;
        clr4 = 1'b0;
        en4 = 1'b0;
        a_left4 = '0;
        b_top4 = '0;
        clr2 = 1'b0;
        en2 = 1'b0;
        a_left2 = '0;
        b_top2 = '0;
        clr1 = 1'b0;
        en1 = 1'b0;
        a_left1 = '0;
        b_top1 = '0;

        @(negedge clk);
        rst_n = 1'b0;
        clr4 = 1'b1;
        clr2 = 1'b1;
        clr1 = 1'b1;
        @(posedge clk);
        #1;
        rst_n = 1'b1;
        clr4 = 1'b0;
        clr2 = 1'b0;
        clr1 = 1'b0;

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = '0;
                b4[r][cidx] = '0;
            end
        end
        run4("zero", 1'b0);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = (r == cidx) ? 8'sd1 : 8'sd0;
                b4[r][cidx] = (r * 4) + cidx - 7;
            end
        end
        run4("identity", 1'b0);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = (r * 3) + cidx + 1;
                b4[r][cidx] = (r * 2) + cidx + 2;
            end
        end
        run4("positive", 1'b1);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = -((r * 3) + cidx + 1);
                b4[r][cidx] = (cidx[0]) ? -((r * 2) + cidx + 2) : ((r * 2) + cidx + 2);
            end
        end
        run4("negative mixed", 1'b0);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = ((r + cidx) & 1) ? -8'sd128 : 8'sd127;
                b4[r][cidx] = ((r == cidx) || ((r + cidx) & 1)) ? -8'sd128 : 8'sd127;
            end
        end
        run4("extrema", 1'b0);

        for (i = 0; i < 20; i = i + 1) begin
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    a4[r][cidx] = $random(seed);
                    b4[r][cidx] = $random(seed);
                end
            end
            run4("fixed seed random N4", 1'b0);
        end

        a2[0][0] = 8'sd1;  a2[0][1] = -8'sd2;
        a2[1][0] = 8'sd3;  a2[1][1] = 8'sd4;
        b2[0][0] = -8'sd5; b2[0][1] = 8'sd6;
        b2[1][0] = 8'sd7;  b2[1][1] = -8'sd8;
        run2("N2 directed");

        for (i = 0; i < 5; i = i + 1) begin
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    a2[r][cidx] = $random(seed);
                    b2[r][cidx] = $random(seed);
                end
            end
            run2("N2 random");
        end

        run1(4'sd7, -4'sd8, "N1 min");
        run1(-4'sd8, -4'sd8, "N1 square");

        @(negedge clk);
        rst_n = 1'b0;
        en4 = 1'b1;
        a_left4 = {4{8'h7f}};
        b_top4 = {4{8'h7f}};
        @(posedge clk);
        #1;
        tests = tests + 1;
        if ($signed(c4[0 +: 32]) !== 32'sd0) begin
            errors = errors + 1;
            $display("FAIL array reset did not clear accumulator zero slice");
        end
        rst_n = 1'b1;
        en4 = 1'b0;

        finish_test();
    end
endmodule
