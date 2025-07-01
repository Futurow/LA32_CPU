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
//ICache相关信号
wire [127:0] inst_group;
wire [  3:0] inst_group_valid;
wire         icache_out_valid;
wire         icache_out_ready;
//InstBuffer相关信号
wire [127:0] inst_4W;
wire [  3:0] inst_4W_valid;
wire         instbuffer_out_valid;  
wire         instbuffer_out_ready;
PredictUnit predict_unit(
                .clk                 (clk),
                .rst                 (rst),
                .fetch_start_addr    (fetch_start_addr),
                .fetch_pos_valid     (fetch_pos_valid),
                .next_ready          (icache_out_ready),
                .out_valid           (predict_unit_out_valid)
                );
ICache      icache(
                .clk                 (clk),
                .rst                 (rst),
                .fetch_start_addr_in (fetch_start_addr),
                .fetch_pos_valid_in  (fetch_pos_valid),
                .inst_group          (inst_group),
                .inst_group_valid    (inst_group_valid),
                .inst_sram_addr      (inst_sram_addr),
                .inst_sram_rdata     (inst_sram_rdata),
                .pre_valid           (predict_unit_out_valid),
                .next_ready          (instbuffer_out_ready),
                .out_valid           (icache_out_valid),
                .out_ready           (icache_out_ready)
                );          
InstBuffer  #(.DEPTH(4)) instbuffer (
                .clk                (clk),
                .rst                (rst),
                .inst_group         (inst_group),
                .inst_group_valid   (inst_group_valid),
                .inst_4W            (inst_4W),
                .inst_4W_valid      (inst_4W_valid),
                .pre_valid          (icache_out_valid),
                .next_ready         (next_ready),
                .out_valid          (instbuffer_out_valid),
                .out_ready          (instbuffer_out_ready)
                );
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
