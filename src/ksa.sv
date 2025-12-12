`define rst     4'd0
`define s0      4'd1 // compute i_next
`define s1      4'd2 // store i -> send_addr = i and wren = 0 
`define s2      4'd3 // get & store s[i] -> compute j_next
`define s3      4'd4 // store j + s[i] -> send_addr = j and wren = 0
`define s4      4'd5 // get s[j] 
`define s5      4'd6 // store s[j] -> addr = i, wrdata = s[j]
`define s6      4'd7 // addr = j, wrdata = s[i]
`define s7      4'd8
`define done    4'd9

module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

    logic [3:0] pstate, nstate; 
    logic [7:0] sj, si, sj_next, si_next, i, i_next, j, j_next;
    logic rdy_next, wren_next; 
    logic [7:0] key_bytes [2:0];

    // pipeline 
    logic [7:0] sum, pl_sum; 
    logic [1:0] idx, pl_idx; 

    // ===== Register to store values ===== 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            i <= 8'd0;
            j <= 8'd0; 
            rdy <= 1'b1; 
            wren <= 1'b0; 
            si <= 8'd0; 
            sj <= 8'd0; 
            sum <= 8'd0; 
            idx <= 8'd0; 
        end
        else begin
            i <= i_next; 
            j <= j_next; 
            rdy <= rdy_next; 
            wren <= wren_next; 
            si <= si_next; 
            sj <= sj_next; 
            sum <= pl_sum; 
            idx <= pl_idx; 
        end
    end

    // ===== KEY =====
    assign key_bytes[0] = key[23:16];
    assign key_bytes[1] = key[15:8];
    assign key_bytes[2] = key[7:0]; 
    

    // ===== FSM =====
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

        `s0: nstate = `s1; 
        `s1: nstate = `s2; 
        `s2: nstate = `s3; 
        `s3: nstate = `s4; 
        `s4: nstate = `s5;
        `s5: nstate = `s6;
        `s6: nstate = `s7;
        `s7: begin
            if (i == 8'd255) nstate = `done; 
            else nstate = `s0; 
        end
        `done: nstate = `rst; 
        endcase
    end

    always_comb begin
        rdy_next = rdy; 
        i_next = i; 
        j_next = j; 
        wren_next = wren; 
        si_next = si; 
        sj_next = sj; 
        addr = 8'd0; 
        wrdata = 8'd0; 

        pl_sum = sum; 
        pl_idx = idx; 

        case(pstate)
        `rst: begin
            wren_next = 1'b0; 
            i_next = 8'd0; 
            j_next = 8'd0; 
            if (en && rdy) rdy_next = 1'b0; 
            else rdy_next = 1'b1; 
        end
        `s0: begin // output addr = i & wren = 0 to get s[i] next clock cycle
            addr = i[7:0];
            wren_next = 1'b0; 
        end
        `s1: begin // si_next = rddata 
            addr = i[7:0];
            wren_next = 1'b0; 
            si_next = rddata; 
        end
        `s2: begin // pipeline stage 1
            addr = i[7:0]; 
            pl_sum = j + si; 
            // pl_idx = i % 3; 
            // j_next = (j + si + key_bytes[i[7:0] % 2'b11]) % 9'b100000000; 
            wren_next = 1'b0;
        end
        `s3: begin // pipeline stage 2 
            addr = i[7:0]; 
            wren_next = 1'b0;
            pl_sum = sum + key_bytes[idx];
            j_next = pl_sum; 
        end
        `s4: begin // use j to get s[j]
            addr = j[7:0];
            wren_next = 1'b0;  
        end
        `s5: begin
            addr = j[7:0];
            wren_next = 1'b1; // changed to 1 
            sj_next = rddata; 
        end
        `s6: begin // store sj_next = rddata + write s[j] = s[i]
            addr = j[7:0];
            wrdata = si; 
            wren_next = 1'b1; 
        end
        `s7: begin // write s[i] = s[j] and i += 1
            addr = i[7:0]; 
            wrdata = sj; 
            wren_next = 1'b0; 
            i_next = i[7:0] + 8'd1; // put here from s8 
            pl_idx = (idx == 2'd2) ? 2'd0 : idx + 2'd1;
        end
        `done: begin
            rdy_next = 1'b1; 
            wren_next = 1'b0; 
        end
        endcase 
    end


endmodule: ksa
