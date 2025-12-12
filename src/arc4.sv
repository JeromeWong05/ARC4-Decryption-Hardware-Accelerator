`define rst 3'd0
`define s0  3'd1
`define s1  3'd2
`define s2  3'd3
`define s3  3'd4
`define s4  3'd5
`define s5  3'd6
`define done 3'd7


module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, 
            output logic [7:0] pt_wrdata, output logic pt_wren, 
            output logic key_fail);
    
    // protocol logic
    logic rdy_next; 

    // init logic 
    logic en_init, rdy_init, s_wren_init; 
    logic [7:0] s_addr_init, s_wrdata_init; 

    // ksa logic 
    logic en_ksa, rdy_ksa, s_wren_ksa; 
    logic [7:0] s_addr_ksa, s_wrdata_ksa; 

    // prga logic 
    logic en_prga, rdy_prga, s_wren_prga; 
    logic [7:0] s_addr_prga, s_wrdata_prga; 

    // s_mem logic 
    logic s_wren;
    logic [7:0] s_rddata, s_addr, s_wrdata; 

    s_mem s(.address(s_addr), .clock(clk), .data(s_wrdata), 
            .wren(s_wren), .q(s_rddata));

    init i (.clk(clk), .rst_n(rst_n), .en(en_init), .rdy(rdy_init), 
            .addr(s_addr_init), .wrdata(s_wrdata_init), .wren(s_wren_init));

    ksa k (.clk(clk), .rst_n(rst_n), .en(en_ksa), .rdy(rdy_ksa), 
           .key(key), .addr(s_addr_ksa), .rddata(s_rddata), 
           .wrdata(s_wrdata_ksa), .wren(s_wren_ksa));

    prga p(.clk(clk), .rst_n(rst_n), .en(en_prga), .rdy(rdy_prga), .key(key), 
           .s_addr(s_addr_prga), .s_rddata(s_rddata), .s_wrdata(s_wrdata_prga), .s_wren(s_wren_prga), 
           .ct_addr(ct_addr), .ct_rddata(ct_rddata), 
           .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren), 
           .key_fail(key_fail));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rdy <= 1'b1; 
        end
        else begin
            rdy <= rdy_next; 
        end
    end

    logic [2:0] pstate, nstate; 

    always_ff @(posedge clk) begin
        if (!rst_n) pstate <= `rst; 
        else pstate <= nstate; 
    end

    always_comb begin
        nstate = pstate; 
        case(pstate)
        `rst: begin
            if (en && rdy) nstate = `s0; 
            else nstate = `rst; 
        end
        `s0: begin
            if (en_init && rdy_init) nstate =`s1; 
            else nstate = `s0; 
        end
        `s1: begin
            if (rdy_init) nstate = `s2; 
            else nstate = `s1; 
        end
        `s2: begin
            if (en_ksa && rdy_ksa) nstate = `s3; 
            else nstate = `s2; 
        end
        `s3: begin
            if (rdy_ksa) nstate = `s4; 
            else nstate = `s3; 
        end
        `s4: begin
            if (en_prga && rdy_prga) nstate = `s5; 
            else nstate = `s4; 
        end
        `s5: begin
            if (rdy_prga) nstate = `done; 
            else nstate = `s5; 
        end
        `done: nstate = `rst; 
        endcase
    end

    always_comb begin
        en_init = 1'b0; 
        en_ksa = 1'b0; 
        en_prga = 1'b0;

        s_wren = 1'b0; 
        s_addr = 8'd0; 
        s_wrdata = 8'd0; 

        rdy_next = rdy; 

        case(pstate)
        `rst: begin
            if (en && rdy) rdy_next = 1'b0; 
            else rdy_next = 1'b1; 
        end
        `s0: begin
            rdy_next = 1'b0; 
            en_init = 1'b1; 
        end
        `s1: begin // init 
            en_init = 1'b0; 
            s_addr = s_addr_init; 
            s_wren = s_wren_init; 
            s_wrdata = s_wrdata_init; 
        end
        `s2: begin // ksa 
            en_ksa = 1'b1; 
            s_addr = s_addr_ksa; 
            s_wren = s_wren_ksa; 
            s_wrdata = s_wrdata_ksa; 
        end
        `s3: begin // ksa 
            s_addr = s_addr_ksa; 
            s_wren = s_wren_ksa; 
            s_wrdata = s_wrdata_ksa; 
        end
        `s4: begin //prga 
            en_prga = 1'b1; 
            s_addr = s_addr_prga; 
            s_wren = s_wren_prga; 
            s_wrdata = s_wrdata_prga; 
        end
        `s5: begin //prga 
            en_prga = 1'b0; 
            s_addr = s_addr_prga; 
            s_wren = s_wren_prga; 
            s_wrdata = s_wrdata_prga; 
        end
        `done: begin
            rdy_next = 1'b1; 
        end
        endcase
    end

endmodule: arc4
