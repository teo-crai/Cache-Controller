module datapath(
  input [31:0]cpu_address; //address we are searching for in cache
  //cache components: 4 ways (banks), 128 sets in each bank
  input valid[0:3][0:127]; //valid bit -> valid[way][index]
  input dirty[0:3][0:127]; //dirty bit for write-back policy
  input [18:0]tag[0:3][0:127]; //19-bit tag
  input [511:0]data[0:3][0:127]; //512 bits of data
  input [1:0]age[0:3][0:127]; //2-bit age register for LRU policy
  );
  //parsing the 32 bit address
  wire [18:0]tag = cpu_address[31:13]; //19 bits
  wire [6:0]index = cpu_address[12:6]; //7 bits
  wire [5:0]offset = cpu_address[5:0]; //6 bits: block offset + word offset
  //result of comparison
  wire hit; 
  //determining if any way was hit
  wire hit_way0, hit_way1, hit_way2, hit_way3;
  assign hit_way0 = valid[0][index] && (tag[0][index] == tag);
  assign hit_way1 = valid[1][index] && (tag[1][index] == tag);
  assign hit_way2 = valid[2][index] && (tag[3][index] == tag);
  assign hit_way3 = valid[3][index] && (tag[3][index] == tag);
  assign hit = hit_way0 | hit_way1 | hit_way2 | hit_way3;
endmodule