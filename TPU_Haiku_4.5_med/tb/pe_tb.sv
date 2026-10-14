module pe_tb();

    localparam CLK_PERIOD = 10;
    localparam WATCHDOG_MAX = 10000;

    // Primary PE: DATA_WIDTH=8, ACC_WIDTH=32
    logic clk;
    logic rst_n;
    logic clr_p, en_p;
    logic signed [7:0] a_in_p, b_in_p;
    logic signed [7:0] a_out_p, b_out_p;
    logic signed [31:0] acc_p;

    // Secondary PE: DATA_WIDTH=6, ACC_WIDTH=16
    logic clr_s, en_s;
    logic signed [5:0] a_in_s, b_in_s;
    logic signed [5:0] a_out_s, b_out_s;
    logic signed [15:0] acc_s;

    int tests = 0;
    int errors = 0;

    // Instantiate primary PE
    pe #(.DATA_WIDTH(8), .ACC_WIDTH(32)) pe_primary (
        .clk(clk), .rst_n(rst_n), .clr(clr_p), .en(en_p),
        .a_in(a_in_p), .b_in(b_in_p),
        .a_out(a_out_p), .b_out(b_out_p), .acc(acc_p)
    );

    // Instantiate secondary PE with non-default DATA_WIDTH
    pe #(.DATA_WIDTH(6), .ACC_WIDTH(16)) pe_secondary (
        .clk(clk), .rst_n(rst_n), .clr(clr_s), .en(en_s),
        .a_in(a_in_s), .b_in(b_in_s),
        .a_out(a_out_s), .b_out(b_out_s), .acc(acc_s)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Watchdog
    initial begin
        #(WATCHDOG_MAX * CLK_PERIOD);
        $display("FAIL: Timeout");
        errors = errors + 1;
        $finish;
    end

    task cycle;
        @(posedge clk);
        #1;
    endtask

    task check_32(string label, logic signed [31:0] actual, logic signed [31:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    task check_8(string label, logic signed [7:0] actual, logic signed [7:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    task check_6(string label, logic signed [5:0] actual, logic signed [5:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    task check_16(string label, logic signed [15:0] actual, logic signed [15:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    initial begin
        // Initialize
        rst_n = 0; clr_p = 0; en_p = 0; a_in_p = 0; b_in_p = 0;
        clr_s = 0; en_s = 0; a_in_s = 0; b_in_s = 0;

        cycle;
        cycle;
        @(negedge clk); rst_n = 1;
        cycle;

        // ========== PRIMARY PE TESTS (8-bit, 32-bit ACC) ==========

        // T1: Reset state - acc should be 0, forwarding should be 0
        check_32("T1_Acc", acc_p, 0);
        check_8("T1_A_out", a_out_p, 0);
        check_8("T1_B_out", b_out_p, 0);

        // T2: First enabled cycle with a_in=3, b_in=-4
        // After this edge: acc should be 3*(-4)=-12, a_out=3, b_out=-4
        @(negedge clk); en_p = 1; a_in_p = 3; b_in_p = -4;
        cycle;
        check_32("T2_Acc", acc_p, -12);
        check_8("T2_A_out", a_out_p, 3);
        check_8("T2_B_out", b_out_p, -4);

        // T3: Change inputs every enabled cycle (a_in=5, b_in=6)
        @(negedge clk); a_in_p = 5; b_in_p = 6;
        cycle;
        check_32("T3_Acc", acc_p, -12 + (5*6)); // -12 + 30 = 18
        check_8("T3_A_out", a_out_p, 5);
        check_8("T3_B_out", b_out_p, 6);

        // T4: Another set of inputs (a_in=2, b_in=3)
        @(negedge clk); a_in_p = 2; b_in_p = 3;
        cycle;
        check_32("T4_Acc", acc_p, 18 + (2*3)); // 18 + 6 = 24
        check_8("T4_A_out", a_out_p, 2);
        check_8("T4_B_out", b_out_p, 3);

        // T5: Negative values (a_in=-8, b_in=7)
        @(negedge clk); a_in_p = -8; b_in_p = 7;
        cycle;
        check_32("T5_Acc", acc_p, 24 + (-8*7)); // 24 - 56 = -32
        check_8("T5_A_out", a_out_p, -8);
        check_8("T5_B_out", b_out_p, 7);

        // T6: Sign extrema (a_in=-128, b_in=127)
        @(negedge clk); a_in_p = -128; b_in_p = 127;
        cycle;
        check_32("T6_Acc", acc_p, -32 + (-128*127)); // -32 - 16256 = -16288
        check_8("T6_A_out", a_out_p, -128);
        check_8("T6_B_out", b_out_p, 127);

        // T7: Clear with en=0 (should not accumulate, should clear)
        @(negedge clk); en_p = 0; clr_p = 1; a_in_p = 10; b_in_p = 10;
        cycle;
        check_32("T7_AccClr", acc_p, 0);
        check_8("T7_A_outClr", a_out_p, 0);
        check_8("T7_B_outClr", b_out_p, 0);

        // T8: Clear overrides enable
        @(negedge clk); clr_p = 1; en_p = 1; a_in_p = 5; b_in_p = 4;
        cycle;
        check_32("T8_ClrOvr", acc_p, 0);
        check_8("T8_A_ClrOvr", a_out_p, 0);
        check_8("T8_B_ClrOvr", b_out_p, 0);

        // T9: Accumulate after clear
        @(negedge clk); clr_p = 0; en_p = 1; a_in_p = 7; b_in_p = 8;
        cycle;
        check_32("T9_AftClr", acc_p, 56);
        check_8("T9_A_AftClr", a_out_p, 7);
        check_8("T9_B_AftClr", b_out_p, 8);

        // T10: Hold (en=0, should not accumulate or forward)
        @(negedge clk); en_p = 0; a_in_p = 100; b_in_p = 100;
        cycle;
        check_32("T10_Hold", acc_p, 56);
        check_8("T10_A_Hold", a_out_p, 7);
        check_8("T10_B_Hold", b_out_p, 8);

        // T11: Resume enable
        @(negedge clk); en_p = 1; a_in_p = 3; b_in_p = 4;
        cycle;
        check_32("T11_Resume", acc_p, 56 + 12); // 56 + 12 = 68
        check_8("T11_A_Resume", a_out_p, 3);
        check_8("T11_B_Resume", b_out_p, 4);

        // T12: Reset overrides all
        @(negedge clk); rst_n = 0; clr_p = 1; en_p = 1; a_in_p = 50; b_in_p = 50;
        cycle;
        check_32("T12_RstAcc", acc_p, 0);
        check_8("T12_RstA", a_out_p, 0);
        check_8("T12_RstB", b_out_p, 0);

        // T13: Resume after reset
        @(negedge clk); rst_n = 1; clr_p = 0; en_p = 1; a_in_p = 2; b_in_p = 9;
        cycle;
        check_32("T13_AftRst", acc_p, 18);
        check_8("T13_A_AftRst", a_out_p, 2);
        check_8("T13_B_AftRst", b_out_p, 9);

        // ========== SECONDARY PE TESTS (6-bit DATA_WIDTH, 16-bit ACC) ==========

        // T14: Secondary PE reset
        @(negedge clk); clr_s = 1;
        cycle;
        check_16("T14_S_ClrAcc", acc_s, 0);
        check_6("T14_S_ClrA", a_out_s, 0);
        check_6("T14_S_ClrB", b_out_s, 0);

        // T15: Secondary PE - simple multiplication (4*5=20)
        @(negedge clk); clr_s = 0; en_s = 1; a_in_s = 4; b_in_s = 5;
        cycle;
        check_16("T15_S_Acc", acc_s, 20);
        check_6("T15_S_A", a_out_s, 4);
        check_6("T15_S_B", b_out_s, 5);

        // T16: Secondary PE - accumulate (-7*3=-21, 20-21=-1)
        @(negedge clk); a_in_s = -7; b_in_s = 3;
        cycle;
        check_16("T16_S_Acc", acc_s, -1);
        check_6("T16_S_A", a_out_s, -7);
        check_6("T16_S_B", b_out_s, 3);

        // T17: Secondary PE - wraparound test (-32*(-32)=1024, wraps to -32768 after accumulated)
        @(negedge clk); clr_s = 1;
        cycle;
        @(negedge clk); clr_s = 0; en_s = 1; a_in_s = -32; b_in_s = -32;
        cycle;
        check_16("T17_S_Wrap1", acc_s, 1024);
        check_6("T17_S_A_Wrap", a_out_s, -32);
        check_6("T17_S_B_Wrap", b_out_s, -32);

        // T18: Multiple products on secondary PE
        @(negedge clk); a_in_s = 10; b_in_s = 6;
        cycle;
        check_16("T18_S_Multi", acc_s, 1024 + 60); // 1084
        check_6("T18_S_A_Multi", a_out_s, 10);
        check_6("T18_S_B_Multi", b_out_s, 6);

        // ========== DETERMINISTIC RANDOM CYCLES (using fixed values that appear random) ==========

        @(negedge clk); clr_p = 1;
        cycle;

        begin
            logic signed [7:0] test_a_vals [8] = '{15, -42, 63, 11, -99, 88, -1, 122};
            logic signed [7:0] test_b_vals [8] = '{-33, 77, -18, 44, -66, 29, 81, -55};
            logic signed [31:0] ref_acc = 0;
            logic signed [7:0] ref_a = 0, ref_b = 0;

            for (int i = 0; i < 8; i++) begin
                @(negedge clk); clr_p = 0; en_p = 1;
                a_in_p = test_a_vals[i];
                b_in_p = test_b_vals[i];
                cycle;

                ref_acc = ref_acc + ($signed(test_a_vals[i]) * $signed(test_b_vals[i]));
                ref_a = test_a_vals[i];
                ref_b = test_b_vals[i];

                check_32($sformatf("RandAcc%0d", i), acc_p, ref_acc);
                check_8($sformatf("RandA%0d", i), a_out_p, ref_a);
                check_8($sformatf("RandB%0d", i), b_out_p, ref_b);
            end
        end

        // ========== FINAL SUMMARY ==========

        @(posedge clk);

        $display("========================================");
        if (errors === 0 && tests > 0) begin
            $display("PE TEST RESULT: PASS");
        end else begin
            $display("PE TEST RESULT: FAIL");
        end
        $display("Tests: %0d", tests);
        $display("Errors: %0d", errors);
        $display("========================================");

        $finish;
    end

endmodule
