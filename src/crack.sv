
`define rst     3'd0 // get message length, ct_addr = 0
`define s0      3'd1 // en = 1, rdy = 0 (already), msg_length_next = ct_rddata 
`define s1      3'd2 // en = 0, if (rdy) -> go s2 
`define s2      3'd3 // chk pt_mem, request pt_mem from 1 
`define done    3'd4 
`define failed  3'd5

module crack #(
    parameter logic [23:0] START_IDX = 24'd0, 
    parameter logic [23:0] STEP = 24'd1
) (
    input logic clk, input logic rst_n,
    input logic en, output logic rdy, 
    output logic [23:0] key, output logic key_valid,
    output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    logic pt_wren_a4, rdy_next, en_a4, rdy_a4, rst_n_a4, key_fail;
    logic [7:0] pt_addr_a4, pt_wrdata_a4, pt_rddata_a4; 
    logic [23:0] key_try, key_try_next, key_max; 

    arc4 a4(.clk(clk), .rst_n(rst_n_a4), .en(en_a4), .rdy(rdy_a4), .key(key_try),
            .ct_addr(ct_addr), .ct_rddata(ct_rddata), 
            .pt_addr(pt_addr_a4), .pt_rddata(pt_rddata_a4), 
            .pt_wrdata(pt_wrdata_a4), .pt_wren(pt_wren_a4), 
            .key_fail(key_fail));

    // maximum value of key_try for this core
    assign key_max = START_IDX + STEP * ((24'hFFFFFF - START_IDX) / STEP);

    // register to hold values 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            key_try <= START_IDX; 
            rdy <= 1'b1; 
        end
        else begin
            key_try <= key_try_next; 
            rdy <= rdy_next; 
        end
    end

   // ===== FSM ===== 
   logic [2:0] pstate, nstate;  
    always_ff @(posedge clk) begin
        if (!rst_n) pstate <= `rst; 
        else pstate <= nstate; 
    end

    always_comb begin
        nstate = pstate; 
        case(pstate)
        `rst: begin
            if (rdy && en) nstate = `s0; 
            else nstate = `rst; 
        end
        `s0: begin 
            if (rdy_a4 && en_a4) nstate = `s1; 
            else nstate = `s0; 
        end
        `s1: begin 
            if (key_fail) nstate = `s2; 
            else if (rdy_a4 && key_fail == 1'b0) nstate = `done; // found the key and done
            else nstate = `s1; 
        end
        `s2: begin // incorrect find, increment key by 1
            if (key_try == key_max) nstate = `failed; 
            else nstate = `s0; 
        end
        `done: begin
            nstate = `done; 
        end
        `failed: begin
            nstate = `failed; 
        end
        default: nstate = `rst; 
        endcase
    end

    always_comb begin
        key_valid = 1'b0; 
        key = 24'd0; 
        en_a4 = 1'b0; 
        key_try_next = key_try; 
        rst_n_a4 = 1'b1; 
        rdy_next = 1'b0; 

        case(pstate)
        `rst: begin
            rst_n_a4 = 1'b0; 
            if (en && rdy) rdy_next = 1'b0; 
            else rdy_next = 1'b1; 
        end
        `s0: begin
            rst_n_a4 = 1'b1; 
            en_a4 = 1'b1; 
        end
        `s1: begin // arc4 in progress 
            en_a4 = 1'b0; 
        end
        `s2: begin // incorrect find, reset k = 0 and key+=1, reset machines 
            rst_n_a4 = 1'b0; 
            // prevent overflow
            key_try_next = (key_try <= 24'hFFFFFF) ? key_try + STEP : key_try; 
        end
        `done: begin
            rdy_next = 1'b1; 
            key_valid = 1'b1; 
            key = key_try; 
        end
        `failed: begin
            rdy_next = 1'b1;
        end

        default: begin
            key_valid = 1'b0; 
            key = 24'd0; 
            en_a4 = 1'b0; 
            key_try_next = key_try; 
            rst_n_a4 = 1'b1; 
            rdy_next = 1'b0; 
        end
        endcase
    end
    

endmodule: crack
