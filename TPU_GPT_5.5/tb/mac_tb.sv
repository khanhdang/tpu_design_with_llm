module mac_tb;
    logic clk;
    logic rst_n;
    logic clr;
    logic en;
    logic signed [7:0] a32;
    logic signed [7:0] b32;
    logic signed [31:0] acc32;
    logic signed [7:0] a16;
    logic signed [7:0] b16;
    logic signed [15:0] acc16;

    logic signed [31:0] ref32;
    logic signed [15:0] ref16;
    integer tests;
    integer errors;
    integer seed;
    logic finished;

    mac #(.DATA_WIDTH(8), .ACC_WIDTH(32)) u_mac32 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a(a32), .b(b32), .acc(acc32)
    );

    mac #(.DATA_WIDTH(8), .ACC_WIDTH(16)) u_mac16 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a(a16), .b(b16), .acc(acc16)
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
        $dumpfile("sim/mac_tb.vcd");
        $dumpvars(0, mac_tb);
    end

    task automatic check32(input [255:0] label);
        begin
            tests = tests + 1;
            if (acc32 !== ref32) begin
                errors = errors + 1;
                $display("FAIL MAC32 %0s: rst_n=%0b clr=%0b en=%0b a=%0d b=%0d expected=%0d got=%0d",
                         label, rst_n, clr, en, a32, b32, ref32, acc32);
            end
        end
    endtask

    task automatic check16(input [255:0] label);
        begin
            tests = tests + 1;
            if (acc16 !== ref16) begin
                errors = errors + 1;
                $display("FAIL MAC16 %0s: rst_n=%0b clr=%0b en=%0b a=%0d b=%0d expected=%0d got=%0d",
                         label, rst_n, clr, en, a16, b16, ref16, acc16);
            end
        end
    endtask

    task automatic step_all(
        input logic next_rst_n,
        input logic next_clr,
        input logic next_en,
        input logic signed [7:0] next_a32,
        input logic signed [7:0] next_b32,
        input logic signed [7:0] next_a16,
        input logic signed [7:0] next_b16,
        input [255:0] label
    );
        logic signed [15:0] prod16;
        begin
            @(negedge clk);
            rst_n = next_rst_n;
            clr = next_clr;
            en = next_en;
            a32 = next_a32;
            b32 = next_b32;
            a16 = next_a16;
            b16 = next_b16;

            prod16 = next_a16 * next_b16;
            if (!next_rst_n) begin
                ref32 = '0;
                ref16 = '0;
            end else if (next_clr) begin
                ref32 = '0;
                ref16 = '0;
            end else if (next_en) begin
                ref32 = ref32 + (next_a32 * next_b32);
                ref16 = ref16 + prod16;
            end

            @(posedge clk);
            #1;
            check32(label);
            check16(label);
        end
    endtask

    task automatic finish_test;
        begin
            if (!finished) begin
                finished = 1'b1;
                $display("========================================");
                if ((errors == 0) && (tests > 0)) begin
                    $display("MAC TEST RESULT: PASS");
                end else begin
                    $display("MAC TEST RESULT: FAIL");
                end
                $display("Tests: %0d", tests);
                $display("Errors: %0d", errors);
                $display("========================================");
                $finish;
            end
        end
    endtask

    initial begin
        logic signed [7:0] ra;
        logic signed [7:0] rb;
        integer i;

        tests = 0;
        errors = 0;
        finished = 1'b0;
        ref32 = '0;
        ref16 = '0;
        rst_n = 1'b1;
        clr = 1'b0;
        en = 1'b0;
        a32 = '0;
        b32 = '0;
        a16 = '0;
        b16 = '0;
        seed = 32'h4d414330;

        step_all(1'b0, 1'b1, 1'b1, 8'sd7, -8'sd2, 8'sd7, -8'sd2, "reset overrides controls");
        step_all(1'b1, 1'b0, 1'b1, 8'sd0, 8'sd55, 8'sd0, 8'sd55, "zero product");
        step_all(1'b1, 1'b1, 1'b0, 8'sd99, 8'sd2, 8'sd99, 8'sd2, "clear with en zero");
        step_all(1'b1, 1'b0, 1'b1, 8'sd3, 8'sd4, 8'sd3, 8'sd4, "three times four");
        step_all(1'b1, 1'b0, 1'b0, -8'sd3, 8'sd4, -8'sd3, 8'sd4, "enable hold");
        step_all(1'b1, 1'b0, 1'b1, -8'sd3, 8'sd4, -8'sd3, 8'sd4, "negative positive");
        step_all(1'b1, 1'b1, 1'b1, 8'sd127, 8'sd127, 8'sd127, 8'sd127, "clear overrides enable");
        step_all(1'b1, 1'b0, 1'b1, -8'sd128, 8'sd127, -8'sd128, 8'sd127, "signed minimum times maximum");
        step_all(1'b1, 1'b0, 1'b1, -8'sd128, -8'sd128, -8'sd128, -8'sd128, "signed minimum squared");
        step_all(1'b0, 1'b0, 1'b1, 8'sd11, 8'sd11, 8'sd11, 8'sd11, "reset clears after accumulation");

        step_all(1'b1, 1'b1, 1'b0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, "clear before wrap test");
        step_all(1'b1, 1'b0, 1'b1, 8'sd1, 8'sd1, -8'sd128, -8'sd128, "wrap product one");
        step_all(1'b1, 1'b0, 1'b1, 8'sd1, 8'sd1, -8'sd128, -8'sd128, "wrap product two");
        step_all(1'b1, 1'b0, 1'b1, 8'sd1, 8'sd1, -8'sd128, -8'sd128, "wrap product three");

        for (i = 0; i < 100; i = i + 1) begin
            ra = $random(seed);
            rb = $random(seed);
            step_all(1'b1, (i == 25), (i != 26), ra, rb, rb, ra, "fixed seed random");
        end

        finish_test();
    end
endmodule
