module fsm2(
  input clk,rst,read,write,hit,
  output [3:0]st_out
  );
  localparam ST_IDLE=4'b0000; //wait for signals from the cpu (read or write request)
  localparam ST_COMPARE=4'b0001; //try to find tag at the address index in cache memory
  localparam ST_READ_HIT=4'b0010; //read data from cache if tag was found
  localparam ST_READ_MISS=4'b0011; //read newly brought in data
  localparam ST_WRITE_HIT=4'b0100; //write data in cache and set block's dirty bit 
  //(made a change not yet saved in the main memory)
  localparam ST_WRITE_MISS=4'b0101; //write data over newly brought in block and set block's dirty bit
  //(made a change not yet saved in the main memory)
  localparam ST_WRITE_BACK=4'b0110; //data is updated into the memory at a later time(when the cache line is ready to be replaced)
  localparam ST_EVICT=4'b0111; //find victim block according to LRU policy
  //then send block back to main memory; the now empty block's dirty bit is reset
  localparam ST_ALLOCATE=4'b1000;  //bring block to cache from main memory
  
  reg [3:0]st; //current state
  reg [3:0]st_next; //next state
  
  reg dirty; //dirty bit
  
  assign st_out = st;
  
  always @ (posedge clk, posedge rst) begin
    if(rst) begin
      st<=ST_IDLE; 
      dirty<=0;
    end
    else begin
    st<=st_next;
    if(st==ST_WRITE_HIT || st==ST_WRITE_MISS) 
      dirty<=1;
    else if(st==ST_EVICT) 
      dirty<=0;
    end 
  end
  
  //combinational transition block
  always @ (*) begin
    st_next=st;
    case(st)
      ST_IDLE: if(read||write) 
                st_next=ST_COMPARE;
      ST_COMPARE: if(hit) begin 
                    if(read)  
                      st_next=ST_READ_HIT;
                    else if(write)
                      st_next=ST_WRITE_HIT;
                  end
                  else begin
                    if(dirty) 
                      st_next=ST_WRITE_BACK;
                    else 
                      st_next=ST_EVICT;
                  end
      ST_WRITE_BACK: st_next=ST_EVICT;
      ST_EVICT: st_next=ST_ALLOCATE;
      ST_ALLOCATE: if(read) 
                    st_next=ST_READ_MISS;
                   else if(write) 
                    st_next=ST_WRITE_MISS;
      ST_READ_HIT: st_next=ST_IDLE;
      ST_WRITE_HIT: st_next=ST_IDLE;
      ST_READ_MISS: st_next=ST_IDLE;
      ST_WRITE_MISS: st_next=ST_IDLE;
      default:st_next=ST_IDLE;
    endcase
  end
  
endmodule 

module fsm2_tb;
  reg clk, rst, read, write, hit;
  wire [3:0]st_out;
   
  //instantiating the fsm unit
  fsm2 uut (
    .clk(clk),
    .rst(rst),
    .read(read),
    .write(write),
    .hit(hit),
    .st_out(st_out)
  );
   
  //simple 2-row cache
  reg [31:0] cache_line[0:1];
    
  //clock generator
  always #10 clk = ~clk;

  task print_state;
    begin //decodes the current state and prints the corresponding state 
      case(st_out)
        4'b0000: $write("IDLE");
        4'b0001: $write("COMPARE");
        4'b0010: $write("READ_HIT");
        4'b0011: $write("READ_MISS");
        4'b0100: $write("WRITE_HIT");
        4'b0101: $write("WRITE_MISS");
        4'b0110: $write("WRITE_BACK");
        4'b0111: $write("EVICT");
        4'b1000: $write("ALLOCATE");
        default: $write("UNKNOWN");
      endcase
      $write("(dirty=%b) ", uut.dirty);//prints the value of the dirty bit in the current state
    end
  endtask
  
  task run_fsm;
    reg first_pass; //checks if it's the first loop to simulate a do while so we can enter the loop 
    //even if the condition is not yet met(still in the idle state)
    input task_read, task_write, task_hit; 
    
    begin
      //assign task inputs to the fsm inputs
      read <= task_read;
      write <= task_write;
      hit <= task_hit;
       
      //$write("Test (R:%b, W:%b, H:%b) Path: ", task_read, task_write, task_hit);
      
      //print the idle 
      print_state();      
      
      first_pass = 0;//initialise to 0 when fsm is still in the idle state 

      while (first_pass==0 || (st_out != 4'b0000)) begin
        first_pass = 1; //first loop is done->mark as completed
        //now the while only checks for the next idle state which marks the end of the current caching process
        @(posedge clk); //advance 1 clock cycle to the next state
        #1;  
        print_state();  //prints COMPARE on first loop, then subsequent states
      end
      
      $display("");
      
      //reset inputs 
      read  <= 0;
      write <= 0;
      hit   <= 0;
      #10; //spacing between cases
    end
  endtask

  initial begin
    $display("--Cache FSM Simulation--");
    
    //initialising the inputs
    clk = 0;
    rst = 0; 
    read = 0; 
    write = 0; 
    hit = 0;
        
    //initialising cache contents
    cache_line[0] = 32'h00002000;
    cache_line[1] = 32'h00002040;
   
    //initial reset
    #10 rst = 1;
    #10 rst = 0;
    
    //testing all combinations
    $display("TEST 1");
    $display("Request: read from address 00002000 -> READ HIT");
    $display("Initial address: %h", cache_line[0]);
    run_fsm(1, 0, 1); //read hit
    $display("Final address: %h", cache_line[0]);

    $display("");
    $display("Request: read from address 00004000 -> READ MISS");
    $display("Initial address: %h", cache_line[0]);
    run_fsm(1, 0, 0); //read miss
    //emulate allocation from memory
    cache_line[0] = 32'h00004000;
    $display("Final address: %h", cache_line[0]);
    
    $display("");
    $display("Request: write at address 00004000 -> WRITE HIT");
    $display("Initial address: %h", cache_line[0]);
    run_fsm(0, 1, 1); //write hit
    $display("Final address: %h", cache_line[0]);

    $display("");
    $display("Request: write at address FFFE0000 -> WRITE MISS");
    $display("Initial address: %h", cache_line[0]);
    run_fsm(0, 1, 0); //write miss
    //emulate allocate + write
    cache_line[0] = 32'hFFFE0000;
    $display("Final address: %h", cache_line[0]);
    
    #10 rst = 1;
    #10 rst = 0;
    
    $display("");
    $display("TEST 2:");
    $display("Request: read from address 00000040 -> READ MISS");
    $display("Initial address: %h", cache_line[1]);
    run_fsm(1, 0, 0); //read miss
    //emulate allocation from memory
    cache_line[1] = 32'h00000040;
    $display("Final address: %h", cache_line[1]);
    
    $display("");
    $display("Request: write at address 00000040 -> WRITE HIT");
    $display("Initial address: %h", cache_line[1]);
    run_fsm(0, 1, 1); //write hit
    $display("Final address: %h", cache_line[1]);
    
    $display("");
    $display("Request: write at address 00004040 -> WRITE MISS");
    $display("Initial address: %h", cache_line[1]);
    run_fsm(0, 1, 0); //write miss
    //emulate allocate + write
    cache_line[1] = 32'h00004040;
    $display("Final address: %h", cache_line[1]);
    
    $display("");
    $display("Request: read from address 00004040 -> READ HIT");
    $display("Initial address: %h", cache_line[1]);
    run_fsm(1, 0, 1); //read hit
    $display("Final address: %h", cache_line[1]);
 
    $display("--End--");
    $stop;
  end
endmodule