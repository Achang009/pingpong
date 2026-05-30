library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ping_pong is
    Port ( 
        i_clk, i_rst   : in  STD_LOGIC;
        i_btnL, i_btnR : in  STD_LOGIC;
        o_led          : out STD_LOGIC_VECTOR (7 downto 0)
    );
end ping_pong;

architecture Behavioral of ping_pong is

    type t_state is (wait_serve, serve_L, serve_R, play, check_win, win_R, win_L); 
    constant bits : integer := 25; 

    signal state      : t_state;
    signal led        : STD_LOGIC_VECTOR(7 downto 0);
    signal dir        : STD_LOGIC; 
    signal sc_L       : STD_LOGIC_VECTOR(3 downto 0);
    signal sc_R       : STD_LOGIC_VECTOR(3 downto 0);
    signal cnt        : STD_LOGIC_VECTOR(bits-1 downto 0) := (others => '0');
    signal f_clk      : std_logic;
    signal btnL_reg, btnR_reg       : std_logic;
    signal btnL_pulse, btnR_pulse   : std_logic;

begin

    o_led <= led;

    -- 1. 分頻計數器
    proc_divider: process(i_clk, i_rst)
    begin
        if i_rst = '1' then cnt <= (others => '0');
        elsif rising_edge(i_clk) then cnt <= cnt + 1;
        end if;
    end process;
    f_clk <= cnt(bits-1);


    -- 2. 按鍵暫存器
    proc_btn: process(f_clk, i_rst)
    begin
        if i_rst = '1' then
            btnL_reg <= '0';
            btnR_reg <= '0';
        elsif rising_edge(f_clk) then
            btnL_reg <= i_btnL;
            btnR_reg <= i_btnR;
        end if;
    end process;
    btnL_pulse <= '1' when (i_btnL = '1' and btnL_reg = '0') else '0';
    btnR_pulse <= '1' when (i_btnR = '1' and btnR_reg = '0') else '0';


    -- 3. 主狀態機
    proc_fsm: process(f_clk, i_rst)
    begin
        if i_rst = '1' then
            state <= wait_serve;
        elsif rising_edge(f_clk) then
            case state is
                when wait_serve =>
                    if btnL_pulse = '1' then    state <= serve_L; 
                    elsif btnR_pulse = '1' then state <= serve_R; 
                    end if;
                when serve_L | serve_R =>
                    state <= play;
                when play =>    
                    -- 左方失誤：(球往左飛 dir='1' 且漏接) 或 (球不在最左邊卻提前擊打)
                    if (dir = '1' and led = "10000000" and btnL_pulse = '0') or (led /= "10000000" and btnL_pulse = '1') then
                        state <= check_win;
                        
                    -- 右方失誤：(球往右飛 dir='0' 且漏接) 或 (球不在最右邊卻提前擊打)
                    elsif (dir = '0' and led = "00000001" and btnR_pulse = '0') or (led /= "00000001" and btnR_pulse = '1') then
                        state <= check_win;
                    end if;
                when check_win =>
                    -- 檢查是否達到 15 分
                    if sc_L = "1111" then    state <= win_L;
                    elsif sc_R = "1111" then state <= win_R;
                    else                     state <= wait_serve; 
                    end if;
                    
                when win_L | win_R =>
                    state <= state; 
                    
                when others =>  
                    state <= wait_serve;
            end case;
        end if;
    end process;


    -- 4. LED 燈光控制
    proc_led: process(f_clk, i_rst)
    begin
        if i_rst = '1' then led <= "00000000";
        elsif rising_edge(f_clk) then
            case state is
                when wait_serve | check_win | win_L | win_R => 
                    led <= sc_L & sc_R; 
                    
                when serve_L =>
                    led <= "10000000"; 
                when serve_R =>
                    led <= "00000001"; 
                    
                when play =>
                    -- 【修正】嚴格限制只能在最邊緣擊球
                    if led = "10000000" and btnL_pulse = '1' then      led <= "01000000";
                    elsif led = "00000001" and btnR_pulse = '1' then   led <= "00000010";
                    else
                        if dir = '0' then led <= '0' & led(7 downto 1); 
                        else              led <= led(6 downto 0) & '0'; 
                        end if;
                    end if;
                    
                when others => 
                    led <= (others => '0');
            end case;
        end if;
    end process;


    -- 5. 球的移動方向控制
    proc_dir: process(f_clk, i_rst)
    begin
        if i_rst = '1' then dir <= '0';
        elsif rising_edge(f_clk) then
            if state = serve_L then 
                dir <= '0';
            elsif state = serve_R then 
                dir <= '1';
            elsif state = play then
                -- 【修正】嚴格限制只能在最邊緣擊球
                if led = "10000000" and btnL_pulse = '1' then      dir <= '0'; 
                elsif led = "00000001" and btnR_pulse = '1' then   dir <= '1'; 
                end if;
            end if;
        end if;
    end process;


    -- 6. 計分控制
    proc_score: process(f_clk, i_rst)
    begin
        if i_rst = '1' then 
            sc_L <= "0000";
            sc_R <= "0000";
        elsif rising_edge(f_clk) then
            if state = play then
                -- 左方失誤 -> 右方加分
                if (dir = '1' and led = "10000000" and btnL_pulse = '0') or (led /= "10000000" and btnL_pulse = '1') then
                    sc_R <= sc_R + 1;
                -- 右方失誤 -> 左方加分
                elsif (dir = '0' and led = "00000001" and btnR_pulse = '0') or (led /= "00000001" and btnR_pulse = '1') then
                    sc_L <= sc_L + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
