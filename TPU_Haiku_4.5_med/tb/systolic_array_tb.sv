module systolic_array_tb();

    localparam CLK_PERIOD = 10;

    reg clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg rst_n, clr, en;
    reg [31:0] a_left, b_top;
    wire [511:0] c_out;

    integer tests = 0;
    integer errors = 0;
    integer watchdog = 0;
    localparam WATCHDOG_LIMIT = 100000;

    systolic_array #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4))
        array_inst (
            .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
            .a_left(a_left), .b_top(b_top), .c(c_out)
        );

    task check_element(input integer i, input integer j, input integer expected);
        integer actual;
        reg [31:0] expected_bits;
        tests = tests + 1;
        actual = $signed(c_out[(i*4+j)*32 +: 32]);
        expected_bits = expected;
        if (c_out[(i*4+j)*32 +: 32] !== expected_bits) begin
            errors = errors + 1;
            $display("FAIL N4_C[%0d][%0d]: expected=%0d got=%0d", i, j, expected, actual);
        end
    endtask

    initial begin
        integer i, j, k, t;
        integer seed;
        integer A [0:3][0:3], B [0:3][0:3], C [0:3][0:3];

        @(negedge clk); rst_n = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(negedge clk); rst_n = 1;
        @(posedge clk); #1;

        // Test 1: Zero matrices
        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            A[i][j] = 0;
            B[i][j] = 0;
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            C[i][j] = 0;
            for (k = 0; k < 4; k++) begin
                C[i][j] = C[i][j] + A[i][k] * B[k][j];
            end
        end

        @(negedge clk); clr = 1; en = 0;
        @(posedge clk); #1;
        @(negedge clk); clr = 0; en = 1;

        for (t = 0; t <= 9; t = t + 1) begin
            a_left = 0;
            b_top = 0;
            for (i = 0; i < 4; i++) begin
                if ((t - i >= 0) && (t - i < 4))
                    a_left[i*8 +: 8] = A[i][t-i];
            end
            for (j = 0; j < 4; j++) begin
                if ((t - j >= 0) && (t - j < 4))
                    b_top[j*8 +: 8] = B[t-j][j];
            end
            @(posedge clk); #1;
            if (t != 9) @(negedge clk);
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            check_element(i, j, C[i][j]);
        end

        // Test 2: Identity matrices
        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            A[i][j] = (i == j) ? 1 : 0;
            B[i][j] = (i == j) ? 1 : 0;
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            C[i][j] = 0;
            for (k = 0; k < 4; k++) begin
                C[i][j] = C[i][j] + A[i][k] * B[k][j];
            end
        end

        @(negedge clk); clr = 1;
        @(posedge clk); #1;
        @(negedge clk); clr = 0;

        for (t = 0; t <= 9; t = t + 1) begin
            a_left = 0;
            b_top = 0;
            for (i = 0; i < 4; i++) begin
                if ((t - i >= 0) && (t - i < 4))
                    a_left[i*8 +: 8] = A[i][t-i];
            end
            for (j = 0; j < 4; j++) begin
                if ((t - j >= 0) && (t - j < 4))
                    b_top[j*8 +: 8] = B[t-j][j];
            end
            @(posedge clk); #1;
            if (t != 9) @(negedge clk);
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            check_element(i, j, C[i][j]);
        end

        // Test 3: Simple positive values
        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            A[i][j] = i + j + 1;
            B[i][j] = i + j + 1;
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            C[i][j] = 0;
            for (k = 0; k < 4; k++) begin
                C[i][j] = C[i][j] + A[i][k] * B[k][j];
            end
        end

        @(negedge clk); clr = 1;
        @(posedge clk); #1;
        @(negedge clk); clr = 0;

        for (t = 0; t <= 9; t = t + 1) begin
            a_left = 0;
            b_top = 0;
            for (i = 0; i < 4; i++) begin
                if ((t - i >= 0) && (t - i < 4))
                    a_left[i*8 +: 8] = A[i][t-i];
            end
            for (j = 0; j < 4; j++) begin
                if ((t - j >= 0) && (t - j < 4))
                    b_top[j*8 +: 8] = B[t-j][j];
            end
            @(posedge clk); #1;
            if (t != 9) @(negedge clk);
        end

        for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) begin
            check_element(i, j, C[i][j]);
        end

        @(posedge clk);
        $display("========================================");
        if (errors === 0 && tests > 0) begin
            $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
        end else begin
            $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
        end
        $display("Tests: %0d", tests);
        $display("Errors: %0d", errors);
        $display("========================================");
        $finish;
    end

    initial begin
        watchdog = 0;
        forever begin
            @(posedge clk);
            watchdog = watchdog + 1;
            if (watchdog > WATCHDOG_LIMIT) begin
                $display("FAIL: Watchdog timeout");
                errors = errors + 1;
                $finish;
            end
        end
    end

endmodule
