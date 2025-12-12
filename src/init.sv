`define rst 2'd0
`define write 2'd1
`define done 2'd2

module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

    // Logic definition
    logic [7:0] i, i_next; 
    logic [1:0] pstate, nstate; 
    logic rdy_next; 

    // sequential for rdy en protocol
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rdy <= 1'b1; 
            i <= 8'd0; 
        end
        else begin
            rdy <= rdy_next; 
            i <= i_next; 
        end
    end


    // reset 
    always_ff @(posedge clk) begin
        if (!rst_n) pstate <= `rst; 
        else pstate <= nstate; 
    end

    // FSM logic 
    always_comb begin
        nstate = pstate; 
        case(pstate)
        `rst: begin
            if (rdy && en) nstate = `write; 
            else nstate = `rst; 
        end
        `write: begin
            if (i == 8'd255) nstate = `done; 
            else nstate = `write; 
        end
        `done: nstate = `rst; 
        endcase
    end

    // Output 
    always_comb begin
        rdy_next = rdy; 
        i_next = i; 
        addr = i; 
        wrdata = i; 
        wren = 1'b0; 

        case(pstate)
        `rst: begin
            wren = 1'b0; 
            i_next = 8'd0; 
            if (en && rdy) rdy_next = 1'b0; 
            else rdy_next = 1'b1; 
        end
        `write: begin
            rdy_next = 1'b0; 
            wren = 1'b1; 
            i_next = i + 8'd1; 
        end
        `done: begin
            rdy_next = 1'b1; 
            wren = 1'b0; 
            i_next = 8'd0; 
        end
        endcase 
    end



endmodule: init