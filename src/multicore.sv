`define rst  3'd0
`define s0   3'd1
`define s1   3'd2
`define s2   3'd3
`define done 3'd4

module multicore #(
    parameter int N_cores = 8
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    output logic [23:0] key,
    output logic        key_valid,
    output logic [7:0]  ct_addr,
    input  logic [7:0]  ct_rddata
);

    logic pt_wren;
    logic [7:0] pt_addr, pt_wrdata, pt_rddata;

    pt_mem pt(
        .address(pt_addr),
        .clock(clk),
        .data(pt_wrdata),
        .wren(pt_wren),
        .q(pt_rddata)
    );

    logic [N_cores-1:0] rdy_c;
    logic [N_cores-1:0] key_valid_c;
    logic [23:0] key_c [N_cores];

    logic [7:0] cct_addr_c   [N_cores];
    logic [7:0] cct_rddata_c [N_cores];

    logic rdy_next, key_valid_next;
    logic [N_cores-1:0] key_valid_q;

    logic [2:0] pstate, nstate;

    logic copying;
    logic final_en;
    // logic decrypt_started;

    logic [7:0] copy_addr;
    logic [7:0] copy_addr_dly;

    logic winner_found;
    logic [$clog2(N_cores)-1:0] winner_id;

    // pipelined winner info
    logic winner_found_d;
    logic [$clog2(N_cores)-1:0] winner_id_d;

    logic [23:0] key_latched;

    logic final_rdy;
    logic [7:0] ct_addr_final;
    logic [7:0] ct_rddata_final;

    assign ct_rddata_final = cct_rddata_c[0];

    arc4 final_a4(
        .clk(clk),
        .rst_n(rst_n),
        .en(final_en),
        .rdy(final_rdy),
        .key(key_latched),
        .ct_addr(ct_addr_final),
        .ct_rddata(ct_rddata_final),
        .pt_addr(pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren(pt_wren),
        .key_fail()
    );

    logic en_crack;

    genvar i;
    generate
        for (i = 0; i < N_cores; i++) begin : CRACKS
            crack #(
                .START_IDX(i),
                .STEP(N_cores)
            ) c (
                .clk(clk),
                .rst_n(rst_n),
                .en(en_crack),
                .rdy(rdy_c[i]),
                .key(key_c[i]),
                .key_valid(key_valid_c[i]),
                .ct_addr(cct_addr_c[i]),
                .ct_rddata(cct_rddata_c[i])
            );

            logic [7:0] cct_addr_mux;
            logic cct_wren;

            always_comb begin
                if (pstate == `s0) begin
                    cct_addr_mux = copy_addr_dly;
                end else if (pstate == `done && i == 0) begin
                    cct_addr_mux = ct_addr_final;
                end else begin
                    cct_addr_mux = cct_addr_c[i];
                end
            end

            assign cct_wren = (pstate == `s0) && (copy_addr != 8'd0);

            ct_mem core_ct(
                .address(cct_addr_mux),
                .clock(clk),
                .data(ct_rddata),
                .wren(cct_wren),
                .q(cct_rddata_c[i])
            );
        end
    endgenerate

    assign ct_addr = (pstate == `s0) ? copy_addr : 8'd0;

    always_comb begin
        winner_found = 1'b0;
        winner_id = '0;
        for (int j = 0; j < N_cores; j++) begin
            if (!winner_found && key_valid_q[j]) begin
                winner_found = 1'b1;
                winner_id = j[$clog2(N_cores)-1:0];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) pstate <= `rst;
        else pstate <= nstate;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            copy_addr <= 8'd0;
            copy_addr_dly <= 8'd0;
            key_latched <= 24'd0;
            // decrypt_started <= 1'b0;
            rdy <= 1'b1;
            key_valid <= 1'b0;
            winner_found_d <= 1'b0;
            winner_id_d <= '0;
            key_valid_q <= '0; 
        end else begin
            rdy <= rdy_next;
            key_valid <= key_valid_next;

            // copy counter
            if (pstate == `rst && en == 1'b1) begin
                copy_addr <= 8'd0;
                copy_addr_dly <= 8'd0;
            end

            if (pstate == `s0) begin
                copy_addr <= copy_addr + 8'd1;
                copy_addr_dly <= copy_addr;
            end

            // pipeline crack output
            key_valid_q <= key_valid_c; 

            // pipeline winner info
            winner_found_d <= winner_found;
            winner_id_d <= winner_id;

            // latch key one cycle after winner is detected
            if (winner_found_d)
                key_latched <= key_c[winner_id_d];

            // if (pstate != `done) begin
            //     decrypt_started <= 1'b0;
            // end else begin
            //     if (!decrypt_started && final_rdy)
            //         decrypt_started <= 1'b1;
            // end
        end
    end

    always_comb begin
        nstate = pstate;
        case (pstate)
        `rst: begin
            if (rdy && en) nstate = `s0;
            else nstate = `rst;
        end

        `s0: begin
            if (copy_addr == 8'hFF) nstate = `s1;
            else nstate = `s0;
        end

        `s1: begin
            if (winner_found) nstate = `s2;
            else nstate = `s1;
        end

        `s2: nstate = `done; 
        `done: nstate = `done; 

        endcase
    end

    always_comb begin
        copying = 1'b0;
        final_en = 1'b0;
        en_crack = 1'b0; 
        key = key_latched;
        rdy_next = rdy;
        key_valid_next = key_valid;

        case (pstate)
        `rst: begin
            if (en && rdy) rdy_next = 1'b0;
            else rdy_next = 1'b1;
            key_valid_next = 1'b0;
        end

        `s0: begin
            copying = 1'b1;
            key_valid_next = 1'b0;
        end

        `s1: begin
            en_crack = 1'b1; 
            key_valid_next = 1'b0;
        end
        
        `s2: begin
            final_en = 1'b1; 
        end

        `done: begin
            if (final_rdy && !final_en) begin
                rdy_next = 1'b1; 
                key_valid_next = 1'b1; 
            end
        end
        endcase
    end

endmodule
