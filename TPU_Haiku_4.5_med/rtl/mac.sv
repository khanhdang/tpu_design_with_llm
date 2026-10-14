module mac #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    input  logic en,
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0] acc
);

    logic signed [ACC_WIDTH-1:0] acc_next;
    logic signed [2*DATA_WIDTH-1:0] product;

    // Compute product with explicit sign extension to ACC_WIDTH
    assign product = $signed(a) * $signed(b);

    // Priority logic: rst_n > clr > en > hold
    logic signed [ACC_WIDTH-1:0] product_ext;
    assign product_ext = $signed(product);

    assign acc_next = (!rst_n) ? '0 :
                      (clr)    ? '0 :
                      (en)     ? (acc + product_ext) :
                      acc;

    always @(posedge clk) begin
        acc <= acc_next;
    end

endmodule
