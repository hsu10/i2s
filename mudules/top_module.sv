
module top_module;
 // 实例化被测单元
  localparam  CLK_DIVISION = 8'd14;
  localparam  AUDIO_WORD_LEN = 8'd24;
  localparam  AUDIO_FRAME_LEN = 8'd64;

  logic clk;
  logic rst_n;

  // 时钟生成
  localparam CLK_PERIOD = 25000;  // 25000 ps = 25 ns = 40 MHz
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // 被测单元（UUT）接口
  logic enable;
  logic audio_data_i;
  logic [23:0] audio_data_o;
  wire bclk_o, lrclk_o;
  logic new_sample_o;

  i2s_receiver #(
    .I2S_CLK_DIVISION(CLK_DIVISION),
    .I2S_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN),
    .I2S_AUDIO_WORD_LEN(AUDIO_WORD_LEN)
  )
  UUT_REC (
      .clk_i(clk),
      .rst_ni(rst_n),
      .enable_i(enable),
      .audio_data_i(audio_data_i),
      .audio_data_o(audio_data_o),
      .bclk_o(bclk_o),
      .lrclk_o(lrclk_o),
      .new_sample_o(new_sample_o)
  );

 i2s_transmitter #(
    .TRA_CLK_DIVISION(CLK_DIVISION),
    .TRA_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN),
    .TRA_AUDIO_WORD_LEN(AUDIO_WORD_LEN)
  ) UUT_TRA (
        .clk_i(clk),
        .rst_ni(rst_n),
        
        .enable_i(enable),
        .audio_data_i(audio_data),
        
        .wave_o(wave),
        
        .audio_data_o(audio_data_o),
        .audio_lrclk_o(lrclk_o),
        .audio_bclk_o(bclk_o)
    );
  clock_generator  #(
    .CLK_CLK_DIVISION(CLK_DIVISION),
    .CLK_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
  ) clock_gen_inst (
      .clk_i(clk),
      .rst_ni(rst_n),
      .enable_i(enable),
      .bclk_o(bclk_o),
      .lrclk_o(lrclk_o)
  );

  // 文件描述符和测试数据
  int fd,fdw;
  logic [23:0] test_data;
  int error_count;
  bit main_lrclk;
logic [23:0] audio_data;

  
    logic data_check_start;         // triggers always block for serial clock
    int   data_check_cntr;          // counter for read data       
    
    logic [31:0] read_data;         // read data

    localparam FRAME_BITS = 64;     // audio frame (32bit x 2)
    
    // Check serial data at posedge serial clock
    always @ (posedge bclk_o) begin
        if (data_check_start == 1) begin
            read_data[data_check_cntr] = audio_data_o;
            data_check_cntr -= 1;
        end else begin
            data_check_cntr = FRAME_BITS/2 - 1;
        end
    end
    
    // reset counter for half audio frame
    always @ (posedge lrclk_o or negedge lrclk_o) begin
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
        forever @(negedge lrclk_o) begin
            data_check_start = 1;
            forever @(posedge clk) begin
                if (data_check_cntr < 7) begin
                    if (lrclk_o == 0 && left_finished == 0) begin
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
        forever @(posedge lrclk_o or negedge lrclk_o) begin
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
  // 记录器任务

  task automatic send_data(input [23:0] send_data);
    fork
      begin
        test_data = send_data;
        logger($sformatf("Sending data: %b", test_data));

        // Capture the initial state of lrclk_o
        //     initial_lrclk = lrclk_o;

        // Wait for lrclk_o to change (beginning of new frame)
        //    @(lrclk_o !== initial_lrclk);
        //    initial_lrclk=lrclk_o;
        // Send data
        for (int i = 23; i >= 0; i--) begin
          if (lrclk_o == main_lrclk || i == 0) begin
            @(negedge bclk_o);
            audio_data_i = test_data[i];
          end //otherwise end early!
            else begin
            //$display("Error: LRCLK changed before sending all data");
            logger("Error: LRCLK changed before sending all data");
            break;
          end
        end

        logger("Finished sending data");
      end
    join_none
  endtask
  // Task to check received data
  task check_data(input [23:0] expected_data);
    fork
      begin
        @(posedge new_sample_o);

        if (audio_data_o !== expected_data) begin
          logger($sformatf("Error: Expected %b, Got %b", expected_data, audio_data_o));
          error_count++;
        end else begin
          logger($sformatf("Success: Correctly received %b", audio_data_o));
        end
      end
    join_none
  endtask

  initial begin
    fork
        begin
    fd = $fopen("i2s_receiver_tb.log", "w");
    logger("----- I2S RECEIVER TESTBENCH -----");

    // 初始化和复位
    enable = 0;
    rst_n = 0;
    audio_data_i = 0;
    error_count = 0;
    #1000ps;
    rst_n  = 1;
    enable = 1;
    #1000ps;
    main_lrclk = lrclk_o;

    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    send_data(24'b0010_0000_1111_0011_1111_1111);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_1111);
    send_data(24'b0010_0000_1111_0011_1111_1011);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_1011);
    send_data(24'b0010_0000_1111_0011_1111_0111);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_0111);
    #20us;
    if (error_count == 0) begin
      logger("All tests PASSED");
    end else begin
      logger($sformatf("Tests FAILED with %d errors", error_count));
    end

    $fclose(fd);
    $finish;
        end
        begin
              logger("----- I2S MASTER TESTBENCH -----");
        test = RESET;
        fdw = $fopen("i2s_master_tb.log", "w");
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
        $fclose(fdw);
        #100us;
        end
    join




  end
endmodule