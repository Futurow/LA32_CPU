module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
// assign inst_sram_addr = 32'h1C000000;
wire rst = ~resetn;
wire [31:0]  fetch_start_addr;
wire  [3:0]  fetch_pos_valid;
reg          next_ready;
wire         predict_unit_out_valid;
PredictUnit predict_unit(clk,rst,fetch_start_addr,fetch_pos_valid,next_ready,predict_unit_out_valid);
always @(posedge clk ) begin
    if (rst) begin
        next_ready = 1'b0;
    end else begin
        next_ready = ~next_ready;
    end
end
// debug info generate
// assign debug_wb_pc       = pc;
// assign debug_wb_rf_wen   = {4{rf_we}};
// assign debug_wb_rf_wnum  = dest;
// assign debug_wb_rf_wdata = final_result;

endmodule
