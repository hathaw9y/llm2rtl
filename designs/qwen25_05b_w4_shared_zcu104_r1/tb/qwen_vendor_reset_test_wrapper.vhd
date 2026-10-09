library ieee;
use ieee.std_logic_1164.all;
library proc_sys_reset_v5_0_17;
entity qwen_vendor_reset_test_wrapper is
 generic (AUX_ACTIVE_HIGH : integer := 1);
 port (clk, ps_resetn : in std_logic; resetn : out std_logic);
end entity;
architecture sim of qwen_vendor_reset_test_wrapper is
 constant aux_polarity : std_logic := std_logic'val(2+AUX_ACTIVE_HIGH);
begin
 reset_ip : entity proc_sys_reset_v5_0_17.proc_sys_reset
 generic map (C_FAMILY=>"zynquplus",C_EXT_RESET_HIGH=>'0',C_AUX_RESET_HIGH=>aux_polarity)
 port map (slowest_sync_clk=>clk,ext_reset_in=>ps_resetn,aux_reset_in=>'0',mb_debug_sys_rst=>'0',dcm_locked=>'1',
 mb_reset=>open,bus_struct_reset=>open,peripheral_reset=>open,interconnect_aresetn=>open,peripheral_aresetn(0)=>resetn);
end architecture;
