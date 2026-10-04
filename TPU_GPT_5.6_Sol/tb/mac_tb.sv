`timescale 1ns/1ps

module mac_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n32, clr32, en32;
    reg signed [7:0] a32, b32;
    wire signed [31:0] acc32;

    reg rst_n16, clr16, en16;
    reg signed [7:0] a16, b16;
    wire signed [15:0] acc16;

    integer tests = 0;
    integer errors = 0;
    integer cycles = 0;
    integer seed = 32'h13579bdf;
    reg finished = 1'b0;
    reg signed [31:0] ref32 = 0;
    reg signed [15:0] ref16 = 0;

    mac #(.DATA_WIDTH(8), .ACC_WIDTH(32)) dut32 (
        .clk(clk), .rst_n(rst_n32), .clr(clr32), .en(en32),
        .a(a32), .b(b32), .acc(acc32)
    );

    mac #(.DATA_WIDTH(8), .ACC_WIDTH(16)) dut16 (
        .clk(clk), .rst_n(rst_n16), .clr(clr16), .en(en16),
        .a(a16), .b(b16), .acc(acc16)
    );

    task automatic check32;
        input integer r;
        input integer c;
        input integer e;
        input integer av;
        input integer bv;
        reg signed [15:0] product;
        begin
            @(negedge clk);
            rst_n32 = r; clr32 = c; en32 = e; a32 = av; b32 = bv;
            product = $signed(av[7:0]) * $signed(bv[7:0]);
            @(posedge clk); #1;
            if (!r) ref32 = 0;
            else if (c) ref32 = 0;
            else if (e) ref32 = ref32 + product;
            tests = tests + 1;
            if (acc32 !== ref32) begin
                errors = errors + 1;
                $display("MAC32 mismatch rst_n=%0d clr=%0d en=%0d a=%0d b=%0d expected=%0d got=%0d",
                         r, c, e, $signed(a32), $signed(b32), ref32, acc32);
            end
        end
    endtask

    task automatic check16;
        input integer r;
        input integer c;
        input integer e;
        input integer av;
        input integer bv;
        reg signed [15:0] product;
        begin
            @(negedge clk);
            rst_n16 = r; clr16 = c; en16 = e; a16 = av; b16 = bv;
            product = $signed(av[7:0]) * $signed(bv[7:0]);
            @(posedge clk); #1;
            if (!r) ref16 = 0;
            else if (c) ref16 = 0;
            else if (e) ref16 = ref16 + product;
            tests = tests + 1;
            if (acc16 !== ref16) begin
                errors = errors + 1;
                $display("MAC16 mismatch rst_n=%0d clr=%0d en=%0d a=%0d b=%0d expected=%0d got=%0d",
                         r, c, e, $signed(a16), $signed(b16), ref16, acc16);
            end
        end
    endtask

    task automatic summary;
        begin
            if ((errors == 0) && (tests > 0))
                $display("MAC TEST RESULT: PASS");
            else
                $display("MAC TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if ((cycles > 1000) && !finished) begin
            errors = errors + 1;
            finished = 1'b1;
            $display("Watchdog timeout");
            summary();
            $finish;
        end
    end

    integer i;
    integer ra;
    integer rb;
    integer rc;
    initial begin
        rst_n32 = 0; clr32 = 0; en32 = 0; a32 = 0; b32 = 0;
        rst_n16 = 0; clr16 = 0; en16 = 0; a16 = 0; b16 = 0;

        check32(0, 1, 1, 7, 9);
        check32(1, 1, 0, 0, 0);
        check32(1, 0, 1, 0, 99);
        check32(1, 0, 1, 3, 4);
        check32(1, 0, 1, -3, 4);
        check32(1, 0, 1, 3, -4);
        check32(1, 0, 1, -3, -4);
        check32(1, 0, 0, 100, 100);
        check32(1, 1, 1, 127, 127);
        check32(1, 0, 1, -128, 127);
        check32(1, 1, 0, 0, 0);
        check32(1, 0, 1, -128, -128);
        check32(0, 1, 1, 127, 127);
        check32(1, 0, 0, 0, 0);

        check16(0, 1, 1, 1, 1);
        check16(1, 1, 0, 0, 0);
        check16(1, 0, 1, -128, -128);
        check16(1, 0, 1, -128, -128);
        check16(1, 0, 1, -128, -128);
        check16(1, 0, 0, 127, 127);
        check16(1, 1, 1, 127, 127);

        for (i = 0; i < 100; i = i + 1) begin
            seed = (seed * 1103515245 + 12345);
            ra = seed;
            seed = (seed * 1103515245 + 12345);
            rb = seed;
            seed = (seed * 1103515245 + 12345);
            rc = seed;
            check32(1, (rc[4:0] == 0), (rc[0] || rc[2]), ra, rb);
        end

        finished = 1'b1;
        summary();
        $finish;
    end
endmodule
