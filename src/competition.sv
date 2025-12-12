
`define rst     4'd0
`define s0      4'd1 
`define s1      4'd2   
`define s2      4'd3 // successful crack + write 8'hFF to addr 1
`define s3      4'd4 // write addr 2
`define s4      4'd5 // write addr 3
`define s5      4'd6 // write addr 4
`define s6      4'd7 // wait for reset
`define s7      4'd8 // failed  

`define num0 7'b1000000
`define num1 7'b1111001
`define num2 7'b0100100
`define num3 7'b0110000
`define num4 7'b0011001
`define num5 7'b0010010
`define num6 7'b0000010
`define num7 7'b1111000
`define num8 7'b0000000
`define num9 7'b0010000

`define numa 7'b0001000
`define numb 7'b0000011
`define numc 7'b1000110
`define numd 7'b0100001
`define nume 7'b0000110
`define numf 7'b0001110
`define num_ 7'b0111111

module competition (input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // multicore 
    logic clk, rst_n, en, rdy, key_valid; 
    logic [23:0] key; 
    logic rst_n_machine; 

    // CT mem 
    logic [7:0] ct_addr, ct_rddata; 

    // MBOX mem 
    logic mbx_wren; 
    logic [7:0] mbx_addr, mbx_rddata, mbx_wrdata;

    // Crack PLL 
    logic fst_clk, pll_locked; 

    // FSM
    logic [3:0] pstate, nstate; 

    // default assigns
    assign clk = CLOCK_50; 
    assign rst_n = KEY[3];
    assign LEDR[0] = rdy; 
    assign LEDR[4] = (pstate == `rst) ? 1'b1 : 1'b0;  
    assign LEDR[9] = key_valid; 

    crack_pll pll (
		.refclk(clk),
		.rst(1'b0),
		.outclk_0(fst_clk),
		.locked(pll_locked)
	);
    
    ct_mem ct(.address(ct_addr), .clock(fst_clk), 
              .data(8'd0), .wren(1'b0), .q(ct_rddata));

    mbox mbox(.address(mbx_addr), .clock(fst_clk), 
              .data(mbx_wrdata), .wren(mbx_wren), .q(mbx_rddata));

    multicore #(.N_cores(110)) multicore (
                   .clk(fst_clk), .rst_n(rst_n_machine), .en(en), .rdy(rdy), 
                   .key(key), .key_valid(key_valid), 
                   .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    logic [6:0] key0_HEX, key1_HEX, key2_HEX, key3_HEX, key4_HEX, key5_HEX;
    sseg KHEX5(key[23:20], key0_HEX); 
    sseg KHEX4(key[19:16], key1_HEX); 
    sseg KHEX3(key[15:12], key2_HEX); 
    sseg KHEX2(key[11: 8], key3_HEX); 
    sseg KHEX1(key[ 7: 4], key4_HEX); 
    sseg KHEX0(key[ 3: 0], key5_HEX); 

    always_ff @(posedge fst_clk) begin
        if (!rst_n) pstate <= `rst; 
        else pstate <= nstate; 
    end

    always_comb begin
        nstate = pstate; 
        case(pstate)
        `rst: begin
            if (rdy && mbx_rddata == 8'hFF) nstate = `s0; 
            else nstate = `rst; 
        end

        `s0: nstate = `s1; 

        `s1: begin // crack in progress 
            if (rdy && key_valid) nstate = `s2; 
            else if (rdy && key_valid == 1'b0) nstate = `s7; 
            else nstate = `s1; 
        end
        `s2: nstate = `s3; // successful crack 
        `s3: nstate = `s4; 
        `s4: nstate = `s5; 
        `s5: nstate = `s6;  // done writing to mbx + wait for reset 
        `s6: begin
            if (mbx_rddata == 8'h00) nstate = `rst; 
            else nstate = `s6; 
        end
        `s7: nstate = `s7; 
        endcase
    end

    always_comb begin
        en = 1'b0; 
        mbx_addr = 8'd0; 
        mbx_wrdata = 8'd0; 
        mbx_wren = 1'b0; 
        rst_n_machine = 1'b1; 

        HEX0 = 7'b1111111;
        HEX1 = 7'b1111111;
        HEX2 = 7'b1111111;
        HEX3 = 7'b1111111;
        HEX4 = 7'b1111111;
        HEX5 = 7'b1111111;

        case(pstate)
        `rst: begin
            if (mbx_rddata != 8'hFF) rst_n_machine = 1'b0; 
            mbx_addr = 8'd0; 
            mbx_wren = 1'b0; 

            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
            HEX3 = 7'b1111111;
            HEX4 = 7'b1111111;
            HEX5 = 7'b1111111;
        end
        `s0: begin
            en = 1'b1; 
            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
            HEX3 = 7'b1111111;
            HEX4 = 7'b1111111;
            HEX5 = 7'b1111111;
        end
        `s1: begin
            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
            HEX3 = 7'b1111111;
            HEX4 = 7'b1111111;
            HEX5 = 7'b1111111;
        end
        `s2: begin
            mbx_addr = 8'd1; 
            mbx_wrdata = 8'hFF; 
            mbx_wren = 1'b1; 
            HEX5 = key0_HEX;
            HEX4 = key1_HEX;
            HEX3 = key2_HEX;
            HEX2 = key3_HEX;
            HEX1 = key4_HEX;
            HEX0 = key5_HEX;
        end
        `s3: begin
            mbx_addr = 8'd2; 
            mbx_wrdata = key[23:16]; 
            mbx_wren = 1'b1; 
            HEX5 = key0_HEX;
            HEX4 = key1_HEX;
            HEX3 = key2_HEX;
            HEX2 = key3_HEX;
            HEX1 = key4_HEX;
            HEX0 = key5_HEX;
        end
        `s4: begin
            mbx_addr = 8'd3; 
            mbx_wrdata = key[15:8]; 
            mbx_wren = 1'b1; 
            HEX5 = key0_HEX;
            HEX4 = key1_HEX;
            HEX3 = key2_HEX;
            HEX2 = key3_HEX;
            HEX1 = key4_HEX;
            HEX0 = key5_HEX;
        end
        `s5: begin
            mbx_addr = 8'd4; 
            mbx_wrdata = key[7:0]; 
            mbx_wren = 1'b1; 
            HEX5 = key0_HEX;
            HEX4 = key1_HEX;
            HEX3 = key2_HEX;
            HEX2 = key3_HEX;
            HEX1 = key4_HEX;
            HEX0 = key5_HEX;
        end
        `s6: begin
            mbx_addr = 8'd0; 
            mbx_wren = 1'b0; 

            HEX5 = key0_HEX;
            HEX4 = key1_HEX;
            HEX3 = key2_HEX;
            HEX2 = key3_HEX;
            HEX1 = key4_HEX;
            HEX0 = key5_HEX;
        end
        `s7: begin
            HEX5 = `num_;
            HEX4 = `num_;
            HEX3 = `num_;
            HEX2 = `num_;
            HEX1 = `num_;
            HEX0 = `num_;
        end

        default: begin
            en = 1'b0; 
            mbx_addr = 8'd0; 
            mbx_wrdata = 8'd0; 
            mbx_wren = 1'b0; 
            rst_n_machine = 1'b1; 

            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
            HEX3 = 7'b1111111;
            HEX4 = 7'b1111111;
            HEX5 = 7'b1111111;
        end
        endcase
    end
    
endmodule: competition



module sseg(in,segs);
  input [3:0] in;
  output reg [6:0] segs;

  always_comb begin
    case(in)
    4'd0: segs = `num0;
    4'd1: segs = `num1;
    4'd2: segs = `num2;
    4'd3: segs = `num3;
    4'd4: segs = `num4;
    4'd5: segs = `num5;
    4'd6: segs = `num6;
    4'd7: segs = `num7;
    4'd8: segs = `num8;
    4'd9: segs = `num9;
    4'd10: segs = `numa;
    4'd11: segs = `numb;
    4'd12: segs = `numc;
    4'd13: segs = `numd;
    4'd14: segs = `nume;
    4'd15: segs = `numf;
    default: segs = 7'bx;
    endcase
  end
endmodule