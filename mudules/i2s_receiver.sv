module i2s_receiver (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        enable_i,
    input  logic        audio_data_i,
    output logic [23:0] audio_data_o,
    output logic        bclk_o,
    output logic        lrclk_o,
    output logic        new_sample_o
);
    // parameters
    localparam logic [7:0] CLK_DIVISION = 8'd14;
    localparam logic [7:0] BCLK_CNTR_HALF_CC = CLK_DIVISION/2 - 1;
    localparam logic [7:0] BCLK_CNTR_FULL_CC = BCLK_CNTR_HALF_CC * 2 + 1;
    localparam logic [7:0] AUDIO_FRAME_LEN = 8'd48;
    localparam logic [7:0] AUDIO_FRAME_CNTR_HALF = AUDIO_FRAME_LEN/2 - 1;

    // local signals
    logic [7:0]  elapsed_cycles;
    logic [7:0]  frame_cntr;
    logic [23:0] shift_reg;
    logic [23:0] shift_reg_l;
    logic        lrclk_prev;
    logic        bclk_prev;
    logic        audio_data_i_sync;

    logic [1:0] bclk_falling_edge_count;

   // logic neg_edgebclk;
    //logic neg_edgebclk_next;

    typedef enum logic [1:0] {
    IDLE,
    COUNT_BCLK_FALLING_EDGES,
    SET_FLAG,
    RESET_FLAG
} fsm_state_t;

fsm_state_t state, next_state;
logic [1:0] bclk_falling_edge_count;
logic flag;


    // clk generation
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            elapsed_cycles <= BCLK_CNTR_FULL_CC;
            bclk_o <= 1'b0;
            frame_cntr <= AUDIO_FRAME_CNTR_HALF;
            lrclk_o <= 1'b1;
        end else if (enable_i) begin
            elapsed_cycles <= elapsed_cycles - 1;

            if (elapsed_cycles == 0) begin
                bclk_o <= ~bclk_o;
                elapsed_cycles <= BCLK_CNTR_HALF_CC;

                if (bclk_o) begin
                    frame_cntr <= frame_cntr - 1;
                    if (frame_cntr == 0) begin
                        lrclk_o <= ~lrclk_o;
                        frame_cntr <= AUDIO_FRAME_CNTR_HALF;
                    end
                end
            end
        end
    end

    // data synchronization logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            audio_data_i_sync <= 1'b0;
            bclk_prev <= 1'b0;
        end else begin
            audio_data_i_sync <= audio_data_i;
            bclk_prev <= bclk_o;
        end
    end

    // receive data logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            shift_reg <= 24'b0;
            shift_reg_l <= 24'b0;
            lrclk_prev <= 1'b1;
            audio_data_o <= 24'b0;
            new_sample_o <= 1'b0;
          //  neg_edgebclk <= 1'b0;
          //  neg_edgebclk_next <= 1'b0;
        end else if (enable_i) begin
            lrclk_prev <= lrclk_o;
            new_sample_o <= 1'b0;
          //  neg_edgebclk <= (!bclk_o && bclk_prev) && ((lrclk_o && !lrclk_prev)||(!lrclk_o && lrclk_prev));
          //  neg_edgebclk_next <= neg_edgebclk;

            // BCLK posedge detection
            if (!bclk_o && bclk_prev) begin
                shift_reg <= {shift_reg[22:0], audio_data_i_sync};
                shift_reg_l <= {shift_reg_l[22:0], audio_data_i_sync};
            end
            if(flag) begin
                if (!lrclk_o) begin
                    audio_data_o <= shift_reg[23:0];  // only 24 bits are valid
                    new_sample_o <= 1'b1;
                end else begin
                    audio_data_o <= shift_reg_l[23:0];  // only 24 bits are valid
                    new_sample_o <= 1'b1;
                end

/* 
            if (flag) begin
                if (!left_right) begin
                    audio_data_o <= shift_reg;  // only 24 bits are valid
                    new_sample_o <= 1'b1;
                end else begin
                    audio_data_o <= shift_reg_l;  // only 24 bits are valid
                    new_sample_o <= 1'b1;
                end
            end */

            // LRCLK posedge detection
/*             if (lrclk_o && !lrclk_prev) begin
                audio_data_o <= shift_reg[23:0];  // only 24 bits are valid
                new_sample_o <= 1'b1;
            end else if (!lrclk_o && lrclk_prev) begin
                audio_data_o <= shift_reg_l[23:0];  // only 24 bits are valid
                new_sample_o <= 1'b1;
            end */
        end
    end
    end

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
        state <= IDLE;
        bclk_falling_edge_count <= 2'b0;
        flag <= 1'b0;
    end else begin
        // FSM state transition
        case (state)
            IDLE: begin
                if ((lrclk_o && !lrclk_prev)||(!lrclk_o && lrclk_prev)) begin
                    state <= COUNT_BCLK_FALLING_EDGES;
                    bclk_falling_edge_count <= 2'b0;
                end
            end

            COUNT_BCLK_FALLING_EDGES: begin
                if (!bclk_o && bclk_prev) begin
                    bclk_falling_edge_count <= bclk_falling_edge_count + 1;
                    if (bclk_falling_edge_count == 2'b0) begin
                        state <= SET_FLAG;
                    end
                end
            end

            SET_FLAG: begin
                flag <= 1'b1;
                state <= RESET_FLAG;
            end

            RESET_FLAG: begin
                flag <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end


endmodule