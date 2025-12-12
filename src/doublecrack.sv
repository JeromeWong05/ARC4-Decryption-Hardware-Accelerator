`define rst     3'd0 // rst and start c1, c2 
`define s0      3'd1 // wait for c1/c2 to assert key_valid + rdy_c1/c2 OR if both failed
`define s1      3'd2 // pt_addr_c1 = k
`define s2      3'd3 // pt_addr_shared = pt_rddata_c1, pt_wren_shared = 1
`define s3      3'd4 // pt_addr_c2 = k
`define s4      3'd5 // pt_addr_shared = pt_rddata_c2, pt_wren_shared = 1, 
`define done    3'd6
`define failed  3'd7 

module doublecrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata, 
             output logic [7:0] ct_addr_2, input logic [7:0] ct_rddata_2);

    // crack module logic
    logic rdy_c1, key_valid_c1, rdy_c2, key_valid_c2, rdy_next; 
    logic [23:0] key_c1, key_c2, key_next;
    logic [7:0] msg_len1, msg_len2, msg_len; 

    // plaintext memory logic
    logic pt_wren; 
    logic [7:0] pt_addr_c1, pt_rddata_c1; 
    logic [7:0] pt_addr_c2, pt_rddata_c2; 
    logic [7:0] pt_addr, pt_wrdata, pt_rddata;

    // double crack module logic 
    logic [7:0] k, k_next;  


    // this memory must have the length-prefixed plaintext if key_valid
    pt_mem pt(.address(pt_addr), .clock(clk), .data(pt_wrdata), 
                     .wren(pt_wren), .q(pt_rddata));

    // for this task only, you may ADD ports to crack
    crack #(.START_IDX(24'h000000), .STEP(24'd2)) 
            c1(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy_c1),
            .key(key_c1), .key_valid(key_valid_c1), 
            .ct_addr(ct_addr), .ct_rddata(ct_rddata), 
            .dc_addr(pt_addr_c1), .dc_rddata(pt_rddata_c1), .message_length(msg_len1));

    crack #(.START_IDX(24'h000001), .STEP(24'd2))
            c2(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy_c2),
            .key(key_c2), .key_valid(key_valid_c2), 
            .ct_addr(ct_addr_2), .ct_rddata(ct_rddata_2), 
            .dc_addr(pt_addr_c2), .dc_rddata(pt_rddata_c2), .message_length(msg_len2));
    
    // ===== Registers =====
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rdy <= 1'b1; 
            k <= 8'd0; 
            msg_len <= 8'd0; 
            key <= 24'h000000;
        end
        else begin
            rdy <= rdy_next; 
            k <= k_next; 
            msg_len <= msg_len1; 
            key <= key_next; 
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
            if (rdy && en && rdy_c1 && rdy_c2) nstate = `s0; 
            else nstate = `rst; 
        end
        `s0: begin
            if (rdy_c1 && key_valid_c1) nstate = `s1; 
            else if (rdy_c2 && key_valid_c2) nstate = `s3; 
            else if ((rdy_c1 && key_valid_c1 == 1'b0) && (rdy_c2 && key_valid_c2 == 1'b0)) nstate = `failed; 
            else nstate = `s0; 
        end
        `s1: nstate = `s2; 
        `s2: begin
            if (k < msg_len) nstate = `s1; 
            else if (k == msg_len) nstate = `done; 
            else nstate = `s1; 
        end
        `s3: nstate = `s4; 
        `s4: begin
            if (k < msg_len) nstate = `s3; 
            else if (k == msg_len) nstate = `done; 
            else nstate = `s3; 
        end
        `done: nstate = `done; 
        `failed: nstate = `failed; 
        endcase
    end

    always_comb begin
        k_next = k; 
        rdy_next = rdy; 
        key_next = key; 
        key_valid = 1'b0; 
        pt_addr = 8'd0; 
        pt_wrdata = 8'd0; 
        pt_wren = 1'b0; 
        pt_addr_c1 = 8'd0; 
        pt_addr_c2 = 8'd0; 


        case(pstate)
        `rst: begin
        if (en && rdy) rdy_next = 1'b0; 
        else rdy_next = 1'b1; 
        end
        // s0 no need output 
        `s1: begin // c1 done 
            key_next = key_c1; 
            pt_addr_c1 = k; 
            pt_addr = k; 
        end
        `s2: begin
            pt_addr_c1 = k; 
            pt_addr = k; 
            pt_wrdata = pt_rddata_c1; 
            pt_wren = 1'b1; 
            k_next = k + 8'd1; 
        end
        `s3: begin // c2 done
            key_next = key_c2; 
            pt_addr_c2 = k; 
            pt_addr = k; 
        end
        `s4: begin
            pt_addr = k; 
            pt_addr_c2 = k; 
            pt_wrdata = pt_rddata_c2; 
            pt_wren = 1'b1; 
            k_next = k + 8'd1;
        end
        `done: begin
            key_valid = 1'b1; 
            rdy_next = 1'b1; 
        end
        `failed: begin
            rdy_next = 1'b1; 
        end
        default: begin
            k_next = k; 
            rdy_next = rdy; 
            key_next = key; 
            key_valid = 1'b0; 
            pt_addr = 8'd0; 
            pt_wrdata = 8'd0; 
            pt_wren = 1'b0; 
            pt_addr_c1 = 8'd0; 
            pt_addr_c2 = 8'd0; 
        end
        endcase

    end

endmodule: doublecrack


