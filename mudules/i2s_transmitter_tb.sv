
`timescale 1ps / 1ps

module i2s_transmitter_tb;
  localparam  CLK_DIVISION = 8'd14;
  localparam  AUDIO_WORD_LEN = 8'd24;
  localparam  AUDIO_FRAME_LEN = 8'd64;
    // questa sim required
    logic clk;          
    logic rst_n;
    logic [7:0] led;


    // Clock generation
    localparam CLK_PERIOD = 25000; // 25000 ps = 25 ns = 40 MHz

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Unit Under Test
    logic enable;
    logic [23:0] audio_data;
    
    wire audio_data_o, audio_lrclk_o, audio_bclk_o;
    wire [23:0] wave;

    i2s_transmitter #(
    .TRA_CLK_DIVISION(CLK_DIVISION),
    .TRA_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN),
    .TRA_AUDIO_WORD_LEN(AUDIO_WORD_LEN)
  ) UUT (
        .clk_i(clk),
        .rst_ni(rst_n),
        
        .enable_i(enable),
        .audio_data_i(audio_data),
        
        .wave_o(wave),
        
        .audio_data_o(audio_data_o),
        .audio_lrclk_o(audio_lrclk_o),
        .audio_bclk_o(audio_bclk_o)
    );

    clock_generator  #(
    .CLK_CLK_DIVISION(CLK_DIVISION),
    .CLK_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
  ) clock_gen_inst (
      .clk_i(clk),
      .rst_ni(rst_n),
      .enable_i(enable),
      .bclk_o(audio_bclk_o),
      .lrclk_o(audio_lrclk_o)
  );

    // Data Self Check
    int fd;     // file descriptor

    logic data_check_start;         // triggers always block for serial clock
    int   data_check_cntr;          // counter for read data       
    
    logic [31:0] read_data;         // read data

    localparam FRAME_BITS = 64;     // audio frame (32bit x 2)
    
    // Check serial data at posedge serial clock
    always @ (posedge audio_bclk_o) begin
        if (data_check_start == 1) begin
            read_data[data_check_cntr] = audio_data_o;
            data_check_cntr -= 1;
        end else begin
            data_check_cntr = FRAME_BITS/2 - 1;
        end
    end
    
    // reset counter for half audio frame
    always @ (posedge audio_lrclk_o or negedge audio_lrclk_o) begin
        data_check_cntr = FRAME_BITS/2 - 1;
    end
    
    // display print + file
    task logger (
        input string line
    ); begin
        $display(line);
        $fdisplay(fd, line);
    end 
    endtask

    // Start data self check
    // End when 24bit are read, then compare
    // Print results
    task data_self_check(
        input logic [23:0] test_data_i
    ); begin
        automatic logic [23:0] test_data_local = test_data_i;
        automatic logic left_finished = 0;
        logger($sformatf("SENT DATA: %b", test_data_local));
        read_data = 32'b0;
        forever @(negedge audio_lrclk_o) begin
            data_check_start = 1;
            forever @(posedge clk) begin
                if (data_check_cntr < 7) begin
                    if (audio_lrclk_o == 0 && left_finished == 0) begin
                        logger($sformatf("READ DATA LEFT CH: %b", read_data[30:7]));
                        if (read_data[30:7] != test_data_local) begin
                            $error("FAIL");
                            $finish;
                        end
                        read_data = 32'b0;
                        left_finished = 1;
                        data_check_cntr = FRAME_BITS/2 - 1;;
                    end else begin
                        logger($sformatf("READ DATA RIGHT CH: %b", read_data[30:7]));
                        if (read_data[30:7] == test_data_local) begin
                            logger("SUCCESS");
                        end else begin
                            $error("FAIL");
                            $finish;
                        end
                        data_check_start = 0;
                        break;
                    end
                end
            end
            
            if (data_check_start == 0) begin
                break;
            end
        end
    end
    endtask

    // Frequency Self Check
    localparam SAMPLE_RATE_FREQ = 44100; // Hz

    task freq_self_check();begin
        automatic int cntr = 0;
        automatic int start_time = 0;
        automatic int sampling_period = 0, sampling_freq = 0;
        forever @(posedge audio_lrclk_o or negedge audio_lrclk_o) begin
            cntr += 1;
            if (cntr == 1) start_time = $realtime/1000; // ps -> ns
            if (cntr == 3) begin
                sampling_period = $realtime/1000 - start_time;
                sampling_freq = 10**9/sampling_period;
                
                logger($sformatf("Desired Sampling Freq: %dHz", SAMPLE_RATE_FREQ));
                logger($sformatf("Real Sampling Freq: %dHz", sampling_freq));
                logger($sformatf("Difference: %dHz < 2000", sampling_freq - SAMPLE_RATE_FREQ));
                
                if ((sampling_freq - SAMPLE_RATE_FREQ) > -2000 && (sampling_freq - SAMPLE_RATE_FREQ) < 2000) begin
                    logger("SUCCESS");
                end else begin
                    $error("FAIL");
                    $finish;
                end
                
                break;
            end
        end
    end
    endtask

    // Testbench Sequence
    typedef enum logic [3:0] {
            RESET, FREQ_TEST, TEST1, TEST2, TEST3, RANDOM, IDLE
    } test_e;
    test_e test;
    
    initial begin
        logger("----- I2S MASTER TESTBENCH -----");
        test = RESET;
        fd = $fopen("i2s_master_tb.log", "w");
        data_check_start = 0;
        enable = 1;
        rst_n = 0;
        audio_data = 24'b0;
        read_data = 32'b0;
        #1000ns;
        rst_n = 1;
        #1000ns;
        
        logger("----- Frequency Test -----");
        test = FREQ_TEST;
        freq_self_check();
        
        logger("----- Manual Sample Data -----");
        test = TEST1;
        audio_data = 24'b1001_1010_0101_1010_1100_0011;
        data_self_check(audio_data);
        test = TEST2;
        audio_data = 24'b0101_1010_0101_1010_1100_0010;
        data_self_check(audio_data);
        test = TEST3;
        audio_data = 24'b1101_1010_0101_1010_1100_0011;
        data_self_check(audio_data);
        
        logger("----- Randomized Sample Data -----");
        test = RANDOM;
        for (int i = 0; i < 99; i++) begin
            audio_data = ($urandom & 24'hffffff);
            data_self_check(audio_data);
        end
        
        test = IDLE;
        audio_data = 24'b0;
        $fclose(fd);
        #100us;
        $finish;
    end

endmodule
