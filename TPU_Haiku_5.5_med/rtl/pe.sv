// Processing element: one MAC plus one-cycle forwarding registers for A and B.
// Reset and clr zero the forwarding registers and the accumulator.
// en advances the forwarding registers and accumulates a_in*b_in; otherwise hold.
module pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         clr,
    input  logic                         en,
    input  logic signed [DATA_WIDTH-1:0] a_in,
    input  logic signed [DATA_WIDTH-1:0] b_in,
    output logic signed [DATA_WIDTH-1:0] a_out,
    output logic signed [DATA_WIDTH-1:0] b_out,
    output logic signed [ACC_WIDTH-1:0]  acc
);
    // MAC uses the same-cycle inputs; no extra input register before the product.
    mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_mac (
        .clk  (clk),
        .rst_n(rst_n),
        .clr  (clr),
        .en   (en),
        .a    (a_in),
        .b    (b_in),
        .acc  (acc)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            a_out <= '0;
            b_out <= '0;
        end else if (clr) begin
            a_out <= '0;
            b_out <= '0;
        end else if (en) begin
            a_out <= a_in;
            b_out <= b_in;
        end
    end
endmodule
