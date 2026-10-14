// Signed multiply-accumulate unit.
// clr zeros acc; otherwise en accumulates a*b; otherwise acc holds.
// Reset takes priority over all controls.
module mac #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         clr,
    input  logic                         en,
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0]  acc
);
    // Signed 2*DATA_WIDTH product, sign-extended to ACC_WIDTH by the
    // signed assignment below before accumulation.
    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0]    product_ext;

    assign product     = a * b;
    assign product_ext = product;

    always @(posedge clk) begin
        if (!rst_n)
            acc <= '0;
        else if (clr)
            acc <= '0;
        else if (en)
            acc <= acc + product_ext;
    end
endmodule
