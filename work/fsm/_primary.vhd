library verilog;
use verilog.vl_types.all;
entity fsm is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        read            : in     vl_logic;
        write           : in     vl_logic;
        hit             : in     vl_logic;
        st_out          : out    vl_logic_vector(3 downto 0)
    );
end fsm;
