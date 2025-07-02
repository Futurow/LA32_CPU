//指令类型
`define INST_NOT     2'b00
`define INST_ALU     2'b01
`define INST_MEM     2'b10
`define INST_BRANCH  2'b11

//算术运算类型
`define ALU_OP_NULL  4'b0000
`define ALU_OP_ADD   4'b0001
`define ALU_OP_SUB   4'b0010
`define ALU_OP_AND   4'B0011
`define ALU_OP_OR    4'B0100
`define ALU_OP_XOR   4'B0101
`define ALU_OP_NOR   4'B0110
//逻辑左移 
`define ALU_OP_SLL   4'B0111
//逻辑右移 
`define ALU_OP_SRL   4'B1000
//算术右移 
`define ALU_OP_SRA   4'B1001
//有符号<比较 
`define ALU_OP_SLT   4'B1010
//无符号<比较 
`define ALU_OP_SLTU  4'B1011
//LU12I
`define ALU_OP_LU12I 4'B1100

//分支条件
`define BRANCH_NULL  3'B000
`define BRANCH_EQ    3'B001
`define BRANCH_NE    3'B010
//无条件跳转
`define BRANCH_J     3'B011