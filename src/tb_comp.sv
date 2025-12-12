`timescale 1ns/1ps

module tb_comp();

    logic clk, err, rst_n, en; 
    logic [1:0] KEY; 
    logic [9:0] SW, LEDR; 
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5; 
    logic [29:0] clk_cnt; 
    logic [7:0] k1, k2, k3; 

    // Max possible states your FSM can have
    localparam int MAX_STATES = 32;

    // Transition coverage matrix
    bit transition_seen [MAX_STATES][MAX_STATES];

    // Counter of unique transitions
    int unique_transition_count = 0;

    // Store previous state for checking transitions
    int prev_state;

    task automatic record_transition(input int prev, input logic [3:0] curr);
        if (!transition_seen[prev][curr]) begin
            transition_seen[prev][curr] = 1;
            unique_transition_count++;

            // $display("NEW TRANSITION DISCOVERED: %0d -> %0d at time %0t", prev, curr, $time);
        end
    endtask



    competition dut (.CLOCK_50(clk), .KEY({rst_n, KEY, en}), .SW(SW), 
               .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
               .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial forever begin
        clk = 1'b1; #10; 
        clk = 1'b0; #10; 
        clk_cnt = clk_cnt + 30'd1; 
    end

    initial begin
        clk_cnt = 30'd0; 
        err = 1'b0; 
        
        $readmemh("test000018.memh", dut.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);
        #20;

        rst_n = 1'b0; #20; 
        rst_n = 1'b1; #20; 
        
        dut.mbox.altsyncram_component.m_default.altsyncram_inst.mem_data[0] = 8'hFF;

        wait(dut.mbox.altsyncram_component.m_default.altsyncram_inst.mem_data[1] == 8'hFF);
        $display("Valid Key Asserted");
        $display("Valid Key is %h", dut.key);

        wait(dut.pstate == 3'd7);
        #40; 
        k1 = dut.mbox.altsyncram_component.m_default.altsyncram_inst.mem_data[2];
        k2 = dut.mbox.altsyncram_component.m_default.altsyncram_inst.mem_data[3];
        k3 = dut.mbox.altsyncram_component.m_default.altsyncram_inst.mem_data[4];

        $display("Saved Key is %h %h %h", k1, k2, k3);

        if (!err) $display("ALL TESTS PASSED, clk - %d", clk_cnt);
        else $display("TESTS FAILED");

        $display("\n================= FSM TRANSITION COVERAGE =================");
        $display("Total unique transitions: %0d\n", unique_transition_count);

        for (int i = 0; i < MAX_STATES; i++) begin
            for (int j = 0; j < MAX_STATES; j++) begin
                if (transition_seen[i][j])
                    $display("  %0d --> %0d", i, j);
            end
        end
        $stop; 
    end

    always @(posedge dut.fst_clk) begin

        // Only record transitions after reset finishes
        if (rst_n) begin
            record_transition(prev_state, dut.pstate);
        end

        prev_state = dut.pstate;
    end


endmodule: tb_comp
