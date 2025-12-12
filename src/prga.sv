

`define rst     4'd0  // i_next = 0, j_next = 0, k_next = 1, ct_addr = 0 to get ciphertext[0]
`define setup1  4'd1  // message_length_next = ct_rddata, pt_addr = 0, pt_wren = 1, pt_wrdata = ct_rddata
`define setup2  4'd2  // pt_addr = 0, pt_wren = 0, pt_wrdata = message_length
`define s0      4'd3  // i_next = (i+1) mod 256, s_addr = i_next, s_wren = 0
`define s1      4'd4  // j_next = (j + s_rddata) mod 256, si_next = s_rddata, s_addr = i, s_wren = 0 (for s[i])
`define s2      4'd5  // si_next = s_rddata, s_addr = j, s_wren = 0 (for s[j])
`define s3      4'd6  // sj_next = s_rddata, s_wren = 1
`define s4      4'd7  // s_addr = j, s_wren = 1, s_wrdata = si
`define s5      4'd8 // s_addr = i, s_wren = 0, s_wrdata = sj
`define s6      4'd9 // s_addr = (si+sj) mod 256, s_wren = 0, ct_addr = k
`define done    4'd10

module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, 
            output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, 
            output logic [7:0] pt_wrdata, output logic pt_wren, 
            output logic key_fail);

    logic [3:0] pstate, nstate; 
    logic [7:0] sj, si, sj_next, si_next, i, i_next, j, j_next, k, k_next;
    logic [7:0] msg_len, msg_len_next, pad, pad_next, cipher, cipher_next; 
    logic rdy_next, s_wren_next, pt_wren_next; 
    logic [7:0] key_bytes [2:0];


    // ===== Registers to hold values ===== 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            i <= 8'd0;
            j <= 8'd0; 
            k <= 8'd1; 
            rdy <= 1'b1; 
            s_wren <= 1'b0; 
            pt_wren <= 1'b0; 
            si <= 8'd0; 
            sj <= 8'd0; 
            msg_len <= 8'd0; 
            pad <= 8'd0; 
            cipher <= 8'd0; 
        end
        else begin
            i <= i_next; 
            j <= j_next; 
            k <= k_next; 
            rdy <= rdy_next; 
            s_wren <= s_wren_next; 
            pt_wren <= pt_wren_next; 
            si <= si_next; 
            sj <= sj_next; 
            msg_len <= msg_len_next;
            pad <= pad_next;
            cipher <= cipher_next;            
        end
    end

    // ===== FSM ==== 
    always_ff @(posedge clk) begin
        if (!rst_n) pstate <= `rst; 
        else pstate <= nstate; 
    end

    always_comb begin
        nstate = pstate; 
        case(pstate)
        `rst: begin
            if (rdy && en) nstate = `setup1; 
            else nstate = `rst; 
        end
        `setup1: nstate = `setup2; 
        `setup2: nstate = `s0; 
        `s0: nstate = `s1; 
        `s1: nstate = `s2; 
        `s2: nstate = `s3; 
        `s3: nstate = `s4; 
        `s4: nstate = `s5; 
        `s5: nstate = `s6; 
        `s6: begin
            if (k == msg_len) nstate = `done; 
            else nstate = `s0; 
        end
        `done: nstate = `rst; 
        endcase
    end

    always_comb begin
        // default logic 
        rdy_next = rdy; 
        i_next = i; 
        j_next = j; 
        k_next = k; 
        s_wren_next = s_wren;
        pt_wren_next = pt_wren; 
        si_next = si; 
        sj_next = sj; 
        msg_len_next = msg_len; 
        pad_next = pad; 
        cipher_next = cipher;  

        // memory outputs 
        s_addr = 8'd0; 
        s_wrdata = 8'd0; 
        s_wren_next = s_wren;

        ct_addr = 8'd0; 

        pt_addr = 8'd0; 
        pt_wrdata = 8'd0; 
        pt_wren_next = pt_wren; 
        
        key_fail = 1'b0; 

        case(pstate)
        `rst: begin // initialize i, j, k (next), get ciphertext[0]
            i_next = 8'd0; j_next = 8'd0; k_next = 8'd1; 
            s_wren_next = 1'b0; pt_wren_next = 1'b0; 
            ct_addr = 8'd0; 

            if (en && rdy) rdy_next = 1'b0; 
            else rdy_next = 1'b1; 
        end
        `setup1: begin // latch ct_rddata, get plaintext[0] = ct_rddata
            msg_len_next = ct_rddata; 
            pt_addr = 8'd0; 
            pt_wren_next = 1'b1; 
            pt_wrdata = ct_rddata; 
        end
        `setup2: begin // finish writing plaintext[0] = message_length
            pt_addr = 8'd0; 
            pt_wren_next = 1'b0; 
            pt_wrdata = ct_rddata; 
        end
        `s0: begin  // calculate i => get s[i] next clk
            i_next = (i[7:0] + 8'd1) % 9'b100000000;
            s_addr = (i[7:0] + 8'd1) % 9'b100000000;
            s_wren_next = 1'b0; 
        end
        `s1: begin // latch si + request s[j]
            si_next = s_rddata; 
            j_next = (j + s_rddata) % 9'b100000000; 
            s_addr = (j + s_rddata) % 9'b100000000; 
            s_wren_next = 1'b0; 
        end
        `s2: begin // save sj
            sj_next = s_rddata; 
            s_wren_next = 1'b1; // added 
        end
        `s3: begin // s[j] = s[i]
            s_addr = j; 
            s_wren_next = 1'b1; 
            s_wrdata = si; 
        end 
        `s4: begin // s[i] = s[j]
            s_addr = i; 
            s_wren_next = 1'b0; // changed from 1 to 0 
            s_wrdata = sj; 
        end
        `s5: begin // get s[(s[i]+s[j]) mod 256] + ciphertext[k]
            s_addr = (si + sj) % 9'b100000000; 
            ct_addr = k; 
            pt_wren_next = 1'b1; 
        end
        `s6: begin
            pad_next = s_rddata; 
            cipher_next = ct_rddata; 
            pt_addr = k; 
            pt_wrdata = s_rddata ^ ct_rddata; 
            pt_wren_next = 1'b0; 
            k_next = k + 8'd1; 
            key_fail = (pt_wrdata >= 8'h20 && pt_wrdata <= 8'h7E) ? 1'b0 : 1'b1;
        end
        `done: begin
            rdy_next = 1'b1; 
        end

        endcase
    end

endmodule: prga
