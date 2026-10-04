module pe_tb;
    logic clk;
    logic rst_n;
    logic clr;
    logic en;
    logic signed [7:0] a8;
    logic signed [7:0] b8;
    logic signed [7:0] a8_out;
    logic signed [7:0] b8_out;
    logic signed [31:0] acc8;
    logic signed [3:0] a4;
    logic signed [3:0] b4;
    logic signed [3:0] a4_out;
    logic signed [3:0] b4_out;
    logic signed [15:0] acc4;

    logic signed [7:0] ref_a8;
    logic signed [7:0] ref_b8;
    logic signed [31:0] ref_acc8;
    logic signed [3:0] ref_a4;
    logic signed [3:0] ref_b4;
    logic signed [15:0] ref_acc4;
    integer tests;
    integer errors;
    integer seed;
    logic finished;

    pe #(.DATA_WIDTH(8), .ACC_WIDTH(32)) u_pe8 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a8), .b_in(b8), .a_out(a8_out), .b_out(b8_out), .acc(acc8)
    );

    pe #(.DATA_WIDTH(4), .ACC_WIDTH(16)) u_pe4 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a4), .b_in(b4), .a_out(a4_out), .b_out(b4_out), .acc(acc4)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        repeat (1000) @(posedge clk);
        if (!finished) begin
            errors = errors + 1;
            $display("FAIL watchdog timeout");
            finish_test();
        end
    end

    initial begin
        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);
    end

    task automatic check_pe(input [255:0] label);
        begin
            tests = tests + 1;
            if ((a8_out !== ref_a8) || (b8_out !== ref_b8) || (acc8 !== ref_acc8)) begin
                errors = errors + 1;
                $display("FAIL PE8 %0s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         label, ref_a8, ref_b8, ref_acc8, a8_out, b8_out, acc8);
            end

            tests = tests + 1;
            if ((a4_out !== ref_a4) || (b4_out !== ref_b4) || (acc4 !== ref_acc4)) begin
                errors = errors + 1;
                $display("FAIL PE4 %0s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         label, ref_a4, ref_b4, ref_acc4, a4_out, b4_out, acc4);
            end
        end
    endtask

    task automatic step_pe(
        input logic next_rst_n,
        input logic next_clr,
        input logic next_en,
        input logic signed [7:0] next_a8,
        input logic signed [7:0] next_b8,
        input logic signed [3:0] next_a4,
        input logic signed [3:0] next_b4,
        input [255:0] label
    );
        begin
            @(negedge clk);
            rst_n = next_rst_n;
            clr = next_clr;
            en = next_en;
            a8 = next_a8;
            b8 = next_b8;
            a4 = next_a4;
            b4 = next_b4;

            if (!next_rst_n) begin
                ref_a8 = '0;
                ref_b8 = '0;
                ref_acc8 = '0;
                ref_a4 = '0;
                ref_b4 = '0;
                ref_acc4 = '0;
            end else if (next_clr) begin
                ref_a8 = '0;
                ref_b8 = '0;
                ref_acc8 = '0;
                ref_a4 = '0;
                ref_b4 = '0;
                ref_acc4 = '0;
            end else if (next_en) begin
                ref_a8 = next_a8;
                ref_b8 = next_b8;
                ref_acc8 = ref_acc8 + (next_a8 * next_b8);
                ref_a4 = next_a4;
                ref_b4 = next_b4;
                ref_acc4 = ref_acc4 + (next_a4 * next_b4);
            end

            @(posedge clk);
            #1;
            check_pe(label);
        end
    endtask

    task automatic finish_test;
        begin
            if (!finished) begin
                finished = 1'b1;
                $display("========================================");
                if ((errors == 0) && (tests > 0)) begin
                    $display("PE TEST RESULT: PASS");
                end else begin
                    $display("PE TEST RESULT: FAIL");
                end
                $display("Tests: %0d", tests);
                $display("Errors: %0d", errors);
                $display("========================================");
                $finish;
            end
        end
    endtask

    initial begin
        logic signed [7:0] ra8;
        logic signed [7:0] rb8;
        logic signed [3:0] ra4;
        logic signed [3:0] rb4;
        integer i;

        tests = 0;
        errors = 0;
        seed = 32'h50453031;
        finished = 1'b0;
        rst_n = 1'b1;
        clr = 1'b0;
        en = 1'b0;
        a8 = '0;
        b8 = '0;
        a4 = '0;
        b4 = '0;
        ref_a8 = '0;
        ref_b8 = '0;
        ref_acc8 = '0;
        ref_a4 = '0;
        ref_b4 = '0;
        ref_acc4 = '0;

        step_pe(1'b0, 1'b1, 1'b1, 8'sd3, -8'sd4, 4'sd3, -4'sd4, "reset priority");
        step_pe(1'b1, 1'b1, 1'b0, 8'sd99, 8'sd99, 4'sd7, 4'sd7, "clear");
        step_pe(1'b1, 1'b0, 1'b1, 8'sd3, -8'sd4, 4'sd3, -4'sd4, "same edge forward and accumulate");
        step_pe(1'b1, 1'b0, 1'b1, -8'sd5, 8'sd6, -4'sd5, 4'sd6, "changed operands");
        step_pe(1'b1, 1'b0, 1'b0, 8'sd100, 8'sd100, 4'sd1, 4'sd1, "hold");
        step_pe(1'b1, 1'b1, 1'b1, 8'sd127, 8'sd127, 4'sd7, 4'sd7, "clear overrides enable");
        step_pe(1'b1, 1'b0, 1'b1, -8'sd128, 8'sd127, -4'sd8, 4'sd7, "signed extrema");
        step_pe(1'b1, 1'b0, 1'b1, -8'sd128, -8'sd128, -4'sd8, -4'sd8, "minimum squared");

        for (i = 0; i < 80; i = i + 1) begin
            ra8 = $random(seed);
            rb8 = $random(seed);
            ra4 = $random(seed);
            rb4 = $random(seed);
            step_pe(1'b1, (i == 20), (i != 21), ra8, rb8, ra4, rb4, "fixed seed random");
        end

        step_pe(1'b0, 1'b0, 1'b1, 8'sd11, 8'sd12, 4'sd2, 4'sd3, "reset after random");
        finish_test();
    end
endmodule
