module tpu_top_tb;
    logic clk;
    logic rst_n;

    logic start4;
    logic [4*4*8-1:0] a_matrix4;
    logic [4*4*8-1:0] b_matrix4;
    logic [4*4*32-1:0] c_matrix4;
    logic busy4;
    logic done4;

    logic start2;
    logic [2*2*8-1:0] a_matrix2;
    logic [2*2*8-1:0] b_matrix2;
    logic [2*2*32-1:0] c_matrix2;
    logic busy2;
    logic done2;

    logic start1;
    logic [1*1*4-1:0] a_matrix1;
    logic [1*1*4-1:0] b_matrix1;
    logic [1*1*16-1:0] c_matrix1;
    logic busy1;
    logic done1;

    logic signed [7:0] a4 [0:3][0:3];
    logic signed [7:0] b4 [0:3][0:3];
    logic signed [31:0] exp4 [0:3][0:3];
    logic signed [7:0] a2 [0:1][0:1];
    logic signed [7:0] b2 [0:1][0:1];
    logic signed [31:0] exp2 [0:1][0:1];
    logic signed [3:0] a1;
    logic signed [3:0] b1;
    logic signed [15:0] exp1;
    logic [4*4*32-1:0] last_c4;
    logic have_last_c4;

    integer tests;
    integer errors;
    integer seed;
    logic finished;

    tpu_top #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4)) u_top4 (
        .clk(clk), .rst_n(rst_n), .start(start4),
        .a_matrix(a_matrix4), .b_matrix(b_matrix4), .c_matrix(c_matrix4),
        .busy(busy4), .done(done4)
    );

    tpu_top #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(2)) u_top2 (
        .clk(clk), .rst_n(rst_n), .start(start2),
        .a_matrix(a_matrix2), .b_matrix(b_matrix2), .c_matrix(c_matrix2),
        .busy(busy2), .done(done2)
    );

    tpu_top #(.DATA_WIDTH(4), .ACC_WIDTH(16), .ARRAY_SIZE(1)) u_top1 (
        .clk(clk), .rst_n(rst_n), .start(start1),
        .a_matrix(a_matrix1), .b_matrix(b_matrix1), .c_matrix(c_matrix1),
        .busy(busy1), .done(done1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        repeat (10000) @(posedge clk);
        if (!finished) begin
            errors = errors + 1;
            $display("FAIL watchdog timeout");
            finish_test();
        end
    end

    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0, tpu_top_tb);
    end

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

    task automatic pack4;
        integer r;
        integer cidx;
        begin
            a_matrix4 = '0;
            b_matrix4 = '0;
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    a_matrix4[(r*4+cidx)*8 +: 8] = a4[r][cidx];
                    b_matrix4[(r*4+cidx)*8 +: 8] = b4[r][cidx];
                end
            end
        end
    endtask

    task automatic poison4;
        integer r;
        integer cidx;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    a_matrix4[(r*4+cidx)*8 +: 8] = 8'sd99 - r - cidx;
                    b_matrix4[(r*4+cidx)*8 +: 8] = -8'sd77 + r + cidx;
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
                    if ($signed(c_matrix4[(r*4+cidx)*32 +: 32]) !== exp4[r][cidx]) begin
                        errors = errors + 1;
                        $display("FAIL tpu4 %0s C[%0d][%0d]: expected=%0d got=%0d",
                                 label, r, cidx, exp4[r][cidx],
                                 $signed(c_matrix4[(r*4+cidx)*32 +: 32]));
                    end
                end
            end
        end
    endtask

    task automatic run4(input [255:0] label, input logic mutate_after_accept);
        integer cycles;
        logic saw_done;
        begin
            compute4();
            pack4();
            @(negedge clk);
            start4 = 1'b1;
            @(posedge clk);
            #1;
            tests = tests + 1;
            if (busy4 !== 1'b1 || done4 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL tpu4 %0s did not become busy after start: busy=%0b done=%0b",
                         label, busy4, done4);
            end
            start4 = 1'b0;
            if (mutate_after_accept) begin
                poison4();
            end

            saw_done = 1'b0;
            for (cycles = 0; cycles < 40 && !saw_done; cycles = cycles + 1) begin
                @(negedge clk);
                start4 = (cycles == 2);
                if (mutate_after_accept) begin
                    poison4();
                end
                @(posedge clk);
                #1;
                if (!done4 && have_last_c4) begin
                    tests = tests + 1;
                    if (c_matrix4 !== last_c4) begin
                        errors = errors + 1;
                        $display("FAIL tpu4 %0s changed published C before capture", label);
                    end
                end
                if (done4) begin
                    saw_done = 1'b1;
                end
            end
            start4 = 1'b0;
            tests = tests + 1;
            if (!saw_done) begin
                errors = errors + 1;
                $display("FAIL tpu4 %0s timed out waiting for done", label);
            end
            tests = tests + 1;
            if (busy4 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL tpu4 %0s busy still high with done", label);
            end
            compare4(label);
            last_c4 = c_matrix4;
            have_last_c4 = 1'b1;

            @(posedge clk);
            #1;
            tests = tests + 1;
            if (done4 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL tpu4 %0s done was not one cycle", label);
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

    task automatic pack2;
        integer r;
        integer cidx;
        begin
            a_matrix2 = '0;
            b_matrix2 = '0;
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    a_matrix2[(r*2+cidx)*8 +: 8] = a2[r][cidx];
                    b_matrix2[(r*2+cidx)*8 +: 8] = b2[r][cidx];
                end
            end
        end
    endtask

    task automatic run2(input [255:0] label);
        integer cycles;
        logic saw_done;
        integer r;
        integer cidx;
        begin
            compute2();
            pack2();
            @(negedge clk);
            start2 = 1'b1;
            @(posedge clk);
            #1;
            start2 = 1'b0;
            saw_done = 1'b0;
            for (cycles = 0; cycles < 20 && !saw_done; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (done2) begin
                    saw_done = 1'b1;
                end
            end
            tests = tests + 1;
            if (!saw_done) begin
                errors = errors + 1;
                $display("FAIL tpu2 %0s timed out waiting for done", label);
            end
            for (r = 0; r < 2; r = r + 1) begin
                for (cidx = 0; cidx < 2; cidx = cidx + 1) begin
                    tests = tests + 1;
                    if ($signed(c_matrix2[(r*2+cidx)*32 +: 32]) !== exp2[r][cidx]) begin
                        errors = errors + 1;
                        $display("FAIL tpu2 %0s C[%0d][%0d]: expected=%0d got=%0d",
                                 label, r, cidx, exp2[r][cidx],
                                 $signed(c_matrix2[(r*2+cidx)*32 +: 32]));
                    end
                end
            end
            @(posedge clk);
            #1;
            tests = tests + 1;
            if (done2 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL tpu2 %0s done was not one cycle", label);
            end
        end
    endtask

    task automatic run1(input logic signed [3:0] aval, input logic signed [3:0] bval, input [255:0] label);
        integer cycles;
        logic saw_done;
        begin
            a1 = aval;
            b1 = bval;
            exp1 = aval * bval;
            a_matrix1 = aval;
            b_matrix1 = bval;
            @(negedge clk);
            start1 = 1'b1;
            @(posedge clk);
            #1;
            start1 = 1'b0;
            saw_done = 1'b0;
            for (cycles = 0; cycles < 10 && !saw_done; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (done1) begin
                    saw_done = 1'b1;
                end
            end
            tests = tests + 1;
            if (!saw_done) begin
                errors = errors + 1;
                $display("FAIL tpu1 %0s timed out waiting for done", label);
            end
            tests = tests + 1;
            if ($signed(c_matrix1) !== exp1) begin
                errors = errors + 1;
                $display("FAIL tpu1 %0s: expected=%0d got=%0d", label, exp1, $signed(c_matrix1));
            end
            @(posedge clk);
            #1;
            tests = tests + 1;
            if (done1 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL tpu1 %0s done was not one cycle", label);
            end
        end
    endtask

    task automatic reset_abort4;
        begin
            @(negedge clk);
            start4 = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            start4 = 1'b0;
            rst_n = 1'b0;
            @(posedge clk);
            #1;
            tests = tests + 1;
            if ((busy4 !== 1'b0) || (done4 !== 1'b0) || (c_matrix4 !== '0)) begin
                errors = errors + 1;
                $display("FAIL tpu4 reset abort: busy=%0b done=%0b c0=%0d",
                         busy4, done4, $signed(c_matrix4[0 +: 32]));
            end
            @(negedge clk);
            rst_n = 1'b1;
            have_last_c4 = 1'b0;
        end
    endtask

    task automatic finish_test;
        begin
            if (!finished) begin
                finished = 1'b1;
                $display("========================================");
                if ((errors == 0) && (tests > 0)) begin
                    $display("TPU_TOP TEST RESULT: PASS");
                end else begin
                    $display("TPU_TOP TEST RESULT: FAIL");
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
        seed = 32'h54505534;
        finished = 1'b0;
        have_last_c4 = 1'b0;
        last_c4 = '0;
        rst_n = 1'b1;
        start4 = 1'b0;
        start2 = 1'b0;
        start1 = 1'b0;
        a_matrix4 = '0;
        b_matrix4 = '0;
        a_matrix2 = '0;
        b_matrix2 = '0;
        a_matrix1 = '0;
        b_matrix1 = '0;

        @(negedge clk);
        rst_n = 1'b0;
        start4 = 1'b1;
        start2 = 1'b1;
        start1 = 1'b1;
        @(posedge clk);
        #1;
        tests = tests + 1;
        if ((busy4 !== 1'b0) || (done4 !== 1'b0) || (c_matrix4 !== '0)) begin
            errors = errors + 1;
            $display("FAIL reset outputs N4");
        end
        tests = tests + 1;
        if ((busy2 !== 1'b0) || (done2 !== 1'b0) || (c_matrix2 !== '0)) begin
            errors = errors + 1;
            $display("FAIL reset outputs N2");
        end
        tests = tests + 1;
        if ((busy1 !== 1'b0) || (done1 !== 1'b0) || (c_matrix1 !== '0)) begin
            errors = errors + 1;
            $display("FAIL reset outputs N1");
        end
        @(negedge clk);
        rst_n = 1'b1;
        start4 = 1'b0;
        start2 = 1'b0;
        start1 = 1'b0;

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
                b4[r][cidx] = (r * 4) + cidx - 8;
            end
        end
        run4("identity with input mutation", 1'b1);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = (r * 4) + cidx + 1;
                b4[r][cidx] = (r + 1) * (cidx + 2);
            end
        end
        run4("positive consecutive", 1'b0);

        for (r = 0; r < 4; r = r + 1) begin
            for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                a4[r][cidx] = -((r * 2) + cidx + 1);
                b4[r][cidx] = ((r + cidx) & 1) ? -((r * 3) + cidx + 1) : ((r * 3) + cidx + 1);
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

        reset_abort4();

        for (i = 0; i < 50; i = i + 1) begin
            for (r = 0; r < 4; r = r + 1) begin
                for (cidx = 0; cidx < 4; cidx = cidx + 1) begin
                    a4[r][cidx] = $random(seed);
                    b4[r][cidx] = $random(seed);
                end
            end
            run4("fixed seed random N4", (i == 0));
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

        finish_test();
    end
endmodule
