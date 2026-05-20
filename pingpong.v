library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ping_pong is
    Port ( 
        i_clk, i_rst   : in  STD_LOGIC;
        i_btnL, i_btnR : in  STD_LOGIC;
        i_btn_next     : in  STD_LOGIC; 
        o_led          : out STD_LOGIC_VECTOR (7 downto 0)
    );
end ping_pong;

architecture Behavioral of ping_pong is

    type t_state is (wait_serve, serve_L, serve_R, play, show_score, win_R, win_L); 
    constant bits : integer := 25; 

    signal state      : t_state;
    signal led        : STD_LOGIC_VECTOR(7 downto 0);
    signal dir        : STD_LOGIC; 
    signal sc_L       : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal sc_R       : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal cnt        : STD_LOGIC_VECTOR(bits-1 downto 0) := (others => '0');
    signal f_clk      : std_logic;
    signal last_winner: std_logic := '0'; 

begin

    o_led <= led;


    proc_divider: process(i_clk, i_rst)
    begin
        if i_rst = '1' then cnt <= (others => '0');
        elsif rising_edge(i_clk) then cnt <= cnt + 1;
        end if;
    end process;
    f_clk <= cnt(bits-1);



    proc_fsm: process(f_clk, i_rst)
    begin
        if i_rst = '1' then
            state <= wait_serve;
        elsif rising_edge(f_clk) then
            case state is
                when wait_serve =>
                    if i_btnL = '1' then    state <= play; 
                    elsif i_btnR = '1' then state <= play; 
                    end if;
                    
                when serve_L =>
                    if i_btnL = '1' then    state <= play; end if;
                when serve_R =>
                    if i_btnR = '1' then    state <= play; end if;
                    
                when play =>    
                    if dir = '1' then  -- 球往左飛 (左方防守)
                        if (led = "10000000" and i_btnL = '0') or (led /= "10000000" and i_btnL = '1') then
                            state <= show_score;
                        end if;
                    else               -- 球往右飛 (右方防守)
                        if (led = "00000001" and i_btnR = '0') or (led /= "00000001" and i_btnR = '1') then
                            state <= show_score;
                        end if;
                    end if;
                    
                when show_score =>
                    if i_btn_next = '1' then
                        if sc_L = "1111" then    state <= win_L;
                        elsif sc_R = "1111" then state <= win_R;
                        else
                            if last_winner = '0' then state <= serve_L;
                            else                      state <= serve_R;
                            end if;
                        end if;
                    end if;
                    
                when win_L | win_R =>
                    state <= state; 
                    
                when others =>  
                    state <= wait_serve;
            end case;
        end if;
    end process;



    proc_led: process(f_clk, i_rst)
    begin
        if i_rst = '1' then led <= "10000001";
        elsif rising_edge(f_clk) then
            case state is
                when wait_serve => 
                    led <= "10000001"; 
                when serve_L =>
                    led <= "10000000"; 
                when serve_R =>
                    led <= "00000001"; 
                when play =>
                    if led = "10000000" and i_btnL = '1' then      led <= "01000000";
                    elsif led = "00000001" and i_btnR = '1' then   led <= "00000010";
                    else
                        if dir = '0' then led <= '0' & led(7 downto 1); 
                        else              led <= led(6 downto 0) & '0'; 
                        end if;
                    end if;
                when show_score | win_L | win_R => 
                    led <= sc_L & sc_R; 
                when others => 
                    led <= (others => '0');
            end case;
        end if;
    end process;



    proc_dir: process(f_clk, i_rst)
    begin
        if i_rst = '1' then dir <= '0';
        elsif rising_edge(f_clk) then
            if state = wait_serve then
                if i_btnL = '1' then     dir <= '0'; 
                elsif i_btnR = '1' then  dir <= '1'; 
                end if;
            elsif state = serve_L then
                if i_btnL = '1' then dir <= '0'; end if; 
            elsif state = serve_R then
                if i_btnR = '1' then dir <= '1'; end if; 
            elsif state = play then
                if led = "10000000" and i_btnL = '1' then      dir <= '0'; 
                elsif led = "00000001" and i_btnR = '1' then   dir <= '1'; 
                end if;
            end if;
        end if;
    end process;



    proc_score: process(f_clk, i_rst)
    begin
        if i_rst = '1' then 
            sc_L <= "0000";
            sc_R <= "0000";
            last_winner <= '0';
        elsif rising_edge(f_clk) then
            if state = play then
                
                -- 當球往右飛(dir='0')，判定右方是否犯規/漏球 -> 左方得分
                if dir = '0' then
                    if (led = "00000001" and i_btnR = '0') or (led /= "00000001" and i_btnR = '1') then
                        sc_L <= sc_L + 1;
                        last_winner <= '0'; -- 紀錄左方贏
                    end if;
                    
                -- 當球往左飛(dir='1')，判定左方是否犯規/漏球 -> 右方得分
                elsif dir = '1' then
                    if (led = "10000000" and i_btnL = '0') or (led /= "10000000" and i_btnL = '1') then
                        sc_R <= sc_R + 1;
                        last_winner <= '1'; -- 紀錄右方贏
                    end if;
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;
