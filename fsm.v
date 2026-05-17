module fsm(
  input clk,rst,read,write,hit,
  output reg 
  );
  localparam ST_IDLE=4'b0000; //wait for signals from the cpu
  localparam ST_COMPARE=4'b0001; //try to find tag in cache memory
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
  
  wire dirty; //dirty bit
  
  always @ (posedge clk, posedge rst)
    if(rst) st<=ST_IDLE; 
    else st<=st_next;
  end
  
  //combinational transition block
  always @ (*) begin
    st_next=st;
    case(st)
      ST_IDLE: if(read||write) st_next=ST_COMPARE;
      ST_COMPARE: if(hit) begin 
                    if(read)  st_next=ST_READ_HIT;
                    else if(write) st_next=ST_WRITE_HIT;
                  end
                  else begin
                    if(dirty&&write) st_next=ST_WRITE_BACK;
                    else st_next=ST_EVICT;
                  end
      ST_WRITE_BACK: st_next=ST_EVICT;
      ST_EVICT: st_next=ST_ALLOCATE;
      ST_ALLOCATE: if(read) st_next=ST_READ_MISS;
                   else if(write) st_next=ST_WRITE_MISS;
      ST_READ_HIT: st_next=ST_IDLE;
      ST_WRITE_HIT: st_next=ST_IDLE;
      ST_READ_MISS: st_next=ST_IDLE;
      ST_WRITE_MISS: st_next=ST_IDLE;
      default:st_next=ST_IDLE;
  end
  
  //combinational output block
  always @ (*) begin
    dirty=0;
    if(st==ST_WRITE_HIT || st==ST_WRITE_MISS) dirty=1;
    else if(st==ST_EVICT) dirty=0;
  end
endmodule  