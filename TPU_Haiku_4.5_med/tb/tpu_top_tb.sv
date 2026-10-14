`timescale 1ns/1ps

module tpu_top_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst4, start4;
    reg [127:0] a_bus4, b_bus4;
    wire [511:0] c_bus4;
    wire busy4, done4;

    reg rst2, start2;
    reg [15:0] a_bus2, b_bus2;
    wire [63:0] c_bus2;
    wire busy2, done2;

    reg rst1, start1;
    reg [7:0] a_bus1, b_bus1;
    wire [15:0] c_bus1;
    wire busy1, done1;

    integer signed a4 [0:3][0:3];
    integer signed b4 [0:3][0:3];
    integer signed expected4 [0:3][0:3];
    integer signed a2 [0:1][0:1];
    integer signed b2 [0:1][0:1];
    integer signed expected2 [0:1][0:1];

    integer tests = 0;
    integer errors = 0;
    integer cycles = 0;
    integer seed = 32'h5eed1234;
    reg finished = 1'b0;

    tpu_top #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4)) dut4 (
        .clk(clk), .rst_n(rst4), .start(start4),
        .a_matrix(a_bus4), .b_matrix(b_bus4), .c_matrix(c_bus4),
        .busy(busy4), .done(done4)
    );
    tpu_top #(.DATA_WIDTH(4), .ACC_WIDTH(16), .ARRAY_SIZE(2)) dut2 (
        .clk(clk), .rst_n(rst2), .start(start2),
        .a_matrix(a_bus2), .b_matrix(b_bus2), .c_matrix(c_bus2),
        .busy(busy2), .done(done2)
    );
    tpu_top #(.DATA_WIDTH(8), .ACC_WIDTH(16), .ARRAY_SIZE(1)) dut1 (
        .clk(clk), .rst_n(rst1), .start(start1),
        .a_matrix(a_bus1), .b_matrix(b_bus1), .c_matrix(c_bus1),
        .busy(busy1), .done(done1)
    );

    task automatic run4;
        input integer case_id;
        input integer inject_busy_start;
        integer i, j, k, wait_cycles;
        reg [511:0] old_result;
        begin
            a_bus4 = 0; b_bus4 = 0;
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    a_bus4[(i*4+j)*8 +: 8] = a4[i][j];
                    b_bus4[(i*4+j)*8 +: 8] = b4[i][j];
                    expected4[i][j] = 0;
                    for (k = 0; k < 4; k = k + 1)
                        expected4[i][j] = expected4[i][j] + a4[i][k] * b4[k][j];
                end
            old_result = c_bus4;
            @(negedge clk); start4 = 1;
            @(posedge clk); #1;
            tests = tests + 1;
            if (busy4 !== 1'b1) begin errors = errors + 1; $display("TPU N4 did not become busy case=%0d", case_id); end
            @(negedge clk); start4 = 0; a_bus4 = '1; b_bus4 = '0;
            wait_cycles = 0;
            while (!done4 && (wait_cycles < 40)) begin
                if (inject_busy_start && (wait_cycles == 3)) start4 = 1;
                else start4 = 0;
                @(posedge clk); #1;
                if (!done4) begin
                    tests = tests + 1;
                    if (c_bus4 !== old_result) begin
                        errors = errors + 1;
                        $display("TPU N4 published result changed early case=%0d cycle=%0d", case_id, wait_cycles);
                    end
                end
                wait_cycles = wait_cycles + 1;
                if (!done4) @(negedge clk);
            end
            start4 = 0;
            tests = tests + 1;
            if (!done4) begin errors = errors + 1; $display("TPU N4 timeout case=%0d seed=%0d", case_id, seed); end
            tests = tests + 1;
            if (busy4 !== 1'b0) begin errors = errors + 1; $display("TPU N4 busy asserted with done case=%0d", case_id); end
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    tests = tests + 1;
                    if (c_bus4[(i*4+j)*32 +: 32] !== expected4[i][j][31:0]) begin
                        errors = errors + 1;
                        $display("TPU N4 case=%0d seed=%0d C[%0d][%0d] expected=%0d got=%0d",
                                 case_id, seed, i, j, expected4[i][j],
                                 $signed(c_bus4[(i*4+j)*32 +: 32]));
                    end
                end
            @(posedge clk); #1;
            tests = tests + 1;
            if (done4 !== 1'b0) begin errors = errors + 1; $display("TPU N4 done wider than one cycle"); end
        end
    endtask

    task automatic run2;
        input integer case_id;
        integer i, j, k, wait_cycles;
        reg [63:0] old_result;
        begin
            a_bus2 = 0; b_bus2 = 0;
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    a_bus2[(i*2+j)*4 +: 4] = a2[i][j];
                    b_bus2[(i*2+j)*4 +: 4] = b2[i][j];
                    expected2[i][j] = 0;
                    for (k = 0; k < 2; k = k + 1)
                        expected2[i][j] = expected2[i][j] + a2[i][k] * b2[k][j];
                end
            old_result = c_bus2;
            @(negedge clk); start2 = 1;
            @(posedge clk); #1;
            @(negedge clk); start2 = 0; a_bus2 = '1; b_bus2 = '0;
            wait_cycles = 0;
            while (!done2 && (wait_cycles < 20)) begin
                @(posedge clk); #1;
                if (!done2) begin
                    tests = tests + 1;
                    if (c_bus2 !== old_result) begin errors = errors + 1; $display("TPU N2 result changed early"); end
                end
                wait_cycles = wait_cycles + 1;
                if (!done2) @(negedge clk);
            end
            tests = tests + 1;
            if (!done2) begin errors = errors + 1; $display("TPU N2 timeout case=%0d", case_id); end
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    tests = tests + 1;
                    if (c_bus2[(i*2+j)*16 +: 16] !== expected2[i][j][15:0]) begin
                        errors = errors + 1;
                        $display("TPU N2 C[%0d][%0d] expected=%0d got=%0d", i,j,expected2[i][j],
                                 $signed(c_bus2[(i*2+j)*16 +: 16]));
                    end
                end
            @(posedge clk); #1;
            tests = tests + 1;
            if (done2 !== 0) begin errors = errors + 1; $display("TPU N2 done wider than one cycle"); end
        end
    endtask

    task automatic run1;
        input integer av;
        input integer bv;
        integer wait_cycles;
        reg signed [15:0] expected;
        begin
            expected = av * bv;
            @(negedge clk); a_bus1 = av; b_bus1 = bv; start1 = 1;
            @(posedge clk); #1;
            @(negedge clk); start1 = 0; a_bus1 = ~av; b_bus1 = ~bv;
            wait_cycles = 0;
            while (!done1 && (wait_cycles < 15)) begin
                @(posedge clk); #1; wait_cycles = wait_cycles + 1;
                if (!done1) @(negedge clk);
            end
            tests = tests + 1;
            if (!done1) begin errors = errors + 1; $display("TPU N1 timeout"); end
            tests = tests + 1;
            if (c_bus1 !== expected) begin
                errors = errors + 1; $display("TPU N1 expected=%0d got=%0d", expected, $signed(c_bus1));
            end
            @(posedge clk); #1;
            tests = tests + 1;
            if (done1 !== 0) begin errors = errors + 1; $display("TPU N1 done wider than one cycle"); end
        end
    endtask

    task automatic summary;
        begin
            if ((errors == 0) && (tests > 0)) $display("TPU_TOP TEST RESULT: PASS");
            else $display("TPU_TOP TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if ((cycles > 20000) && !finished) begin
            errors = errors + 1; finished = 1'b1;
            $display("Watchdog timeout seed=%0d", seed); summary(); $finish;
        end
    end

    integer i, j, n;
    initial begin
        rst4 = 0; start4 = 0; a_bus4 = 0; b_bus4 = 0;
        rst2 = 0; start2 = 0; a_bus2 = 0; b_bus2 = 0;
        rst1 = 0; start1 = 0; a_bus1 = 0; b_bus1 = 0;
        @(posedge clk); #1;
        tests = tests + 3;
        if (c_bus4 !== 0) begin errors = errors + 1; $display("TPU N4 reset output nonzero"); end
        if (c_bus2 !== 0) begin errors = errors + 1; $display("TPU N2 reset output nonzero"); end
        if (c_bus1 !== 0) begin errors = errors + 1; $display("TPU N1 reset output nonzero"); end
        @(negedge clk); rst4 = 1; rst2 = 1; rst1 = 1;

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin a4[i][j] = 0; b4[i][j] = 0; end
        run4(0, 1);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = (i == j); b4[i][j] = (i == j) ? (i+1) : 0;
            end
        run4(1, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = i*4+j+1; b4[i][j] = i+j+1;
            end
        run4(2, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = -(i+j+1); b4[i][j] = i-j-3;
            end
        run4(3, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = ((i+j)&1) ? -(i*4+j+1) : (i*4+j+1);
                b4[i][j] = ((i+j)&1) ? (i+j+2) : -(i+j+2);
            end
        run4(4, 0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a4[i][j] = ((i+j)&1) ? -128 : 127;
                b4[i][j] = ((i*4+j)&1) ? 127 : -128;
            end
        run4(5, 0);

        for (n = 0; n < 50; n = n + 1) begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    seed = seed * 1103515245 + 12345; a4[i][j] = $signed(seed[7:0]);
                    seed = seed * 1103515245 + 12345; b4[i][j] = $signed(seed[7:0]);
                end
            run4(100+n, (n == 17));
        end

        a2[0][0] = 7; a2[0][1] = -8; a2[1][0] = -3; a2[1][1] = 5;
        b2[0][0] = -8; b2[0][1] = 2; b2[1][0] = 7; b2[1][1] = -4;
        run2(0);
        run1(-128, 127);
        run1(-128, -128);

        @(negedge clk); a_bus4 = 128'h01010101010101010101010101010101;
        b_bus4 = 128'h01010101010101010101010101010101; start4 = 1;
        @(posedge clk); #1;
        @(negedge clk); start4 = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst4 = 0;
        @(posedge clk); #1;
        tests = tests + 3;
        if (busy4 !== 0) begin errors = errors + 1; $display("TPU N4 reset did not abort busy"); end
        if (done4 !== 0) begin errors = errors + 1; $display("TPU N4 reset asserted done"); end
        if (c_bus4 !== 0) begin errors = errors + 1; $display("TPU N4 reset did not zero output"); end
        @(negedge clk); rst4 = 1;

        finished = 1'b1;
        summary();
        $finish;
    end
endmodule
