// Signed multiply-accumulate unit.
// Priority: reset, clr, en, hold. rst_n is synchronous, active low.
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

    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0]    product_ext;

    assign product     = a * b;
    // Explicit sign extension of the 2*DATA_WIDTH product to ACC_WIDTH.
    assign product_ext = ACC_WIDTH'(product);

    always @(posedge clk) begin
        if (!rst_n)
            acc <= '0;
        else if (clr)
            acc <= '0;
        else if (en)
            acc <= acc + product_ext;
    end

endmodule
