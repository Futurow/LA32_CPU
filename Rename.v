module Rename (
);
    
endmodule

module sRAT (
    input                   clk,rst,
    input   wire    [4:0]   inst0_rs1,inst0_rs2,
    output  reg     [5:0]   inst0_prs1,inst0_prs2,
    input   wire    [4:0]   inst1_rs1,inst1_rs2,
    output  reg     [5:0]   inst1_prs1,inst1_prs2,
    input   wire    [4:0]   inst2_rs1,inst2_rs2,
    output  reg     [5:0]   inst2_prs1,inst2_prs2,
    input   wire    [4:0]   inst3_rs1,inst3_rs2,
    output  reg     [5:0]   inst3_prs1,inst3_prs2,
    input   wire    [4:0]   inst0_dest,inst1_dest,inst2_dest,inst3_dest,
    input   wire    [5:0]   inst0_preg,inst1_preg,inst2_preg,inst3_preg,//重命名后的寄存器
    input   wire    [3:0]   we,
    output  reg     [5:0]   inst0_pre_reg,inst1_pre_reg,inst2_pre_reg,inst3_pre_reg
    );
    //统一的PRF寄存器重命名方法
    //32个架构寄存器----64个物理寄存器
    reg [5:0] rat [0:31];
    integer i;
    always @(posedge clk ) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rat[i] <= i;
            end
        end else begin
            if (we[3] && inst0_dest != 5'b0) begin
                rat[inst0_dest] <= inst0_preg;
            end
            if (we[2] && inst1_dest != 5'b0) begin
                rat[inst1_dest] <= inst1_preg;
            end
            if (we[1] && inst2_dest != 5'b0) begin
                rat[inst2_dest] <= inst2_preg;
            end
            if (we[0] && inst3_dest != 5'b0) begin
                rat[inst3_dest] <= inst3_preg;
            end
        end
    end
    //RAW 写后读相关性
    always @(*) begin
        inst0_prs1=rat[inst0_rs1];
        inst0_prs2=rat[inst0_rs2]; 
    end

    always @(*) begin
        inst1_prs1 = rat[inst1_rs1];
        inst1_prs2 = rat[inst1_rs2];
        if (we[3]&&(inst0_dest==inst1_rs1)) begin
            inst1_prs1 = inst0_preg;
        end
        if (we[3]&&(inst0_dest==inst1_rs2)) begin
                inst1_prs2 = inst0_preg;
        end
    end

    always @(*) begin
        inst2_prs1=rat[inst2_rs1];
        inst2_prs2=rat[inst2_rs2]; 
        if (we[2]&&(inst1_dest==inst2_rs1)) begin
            inst2_prs1 = inst1_preg;
        end else if(we[3]&&(inst0_dest==inst2_rs1))begin
            inst2_prs1 = inst0_preg;
        end
        if (we[2]&&(inst1_dest==inst2_rs2)) begin
            inst2_prs2 = inst1_preg;
        end else if(we[3]&&(inst0_dest==inst2_rs2))begin
            inst2_prs2 = inst0_preg;
        end
    end
    always @(*) begin
        inst3_prs1=rat[inst3_rs1];
        inst3_prs2=rat[inst3_rs2];
        if (we[1]&&(inst2_dest==inst3_rs1)) begin
            inst3_prs1 = inst2_preg;
        end else if(we[2]&&(inst1_dest==inst3_rs1))begin
            inst3_prs1 = inst1_preg;
        end else if(we[3]&&(inst0_dest==inst3_rs1))begin
            inst3_prs1 = inst0_preg;
        end
        if (we[1]&&(inst2_dest==inst3_rs2)) begin
            inst3_prs2 = inst2_preg;
        end else if(we[2]&&(inst1_dest==inst3_rs2))begin
            inst3_prs2 = inst1_preg;
        end else if(we[3]&&(inst0_dest==inst3_rs2))begin
            inst3_prs2 = inst0_preg;
        end
    end

    //WAW 写后写相关性
    always @(*) begin
        inst0_pre_reg = rat[inst0_dest];
        inst1_pre_reg = rat[inst1_dest];
        inst2_pre_reg = rat[inst2_dest];
        inst3_pre_reg = rat[inst3_dest];
        if (we[3]&&(inst0_dest == inst1_dest)) begin
            inst1_pre_reg = inst0_preg;
        end
        if (we[2]&&(inst1_dest == inst2_dest)) begin
            inst2_pre_reg = inst1_preg;
        end else if (we[3]&&(inst0_dest == inst2_dest)) begin
            inst2_pre_reg = inst0_preg;
        end
        if (we[1]&&(inst2_dest == inst3_dest)) begin
            inst3_pre_reg = inst2_preg;
        end else if (we[2]&&(inst1_dest == inst3_dest)) begin
            inst3_pre_reg = inst1_preg;
        end else if (we[3]&&(inst0_dest == inst3_dest)) begin
            inst3_pre_reg = inst0_preg;
        end
    end
endmodule
