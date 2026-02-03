library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ping_pong is
    Port ( 
        i_clk, i_rst   : in  STD_LOGIC;
        i_btnL, i_btnR : in  STD_LOGIC;
        o_led          : out STD_LOGIC_VECTOR (7 downto 0)
    );
end ping_pong;

architecture Behavioral of ping_pong is

    type t_state is (serve_L, serve_R, play, show_score, win_R, win_L); 
    constant bits : integer := 25; 

    signal state : t_state;
    signal led   : STD_LOGIC_VECTOR(7 downto 0);
    signal dir   : STD_LOGIC; 
    signal sc_L, sc_R : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal cnt   : STD_LOGIC_VECTOR(bits-1 downto 0) := (others => '0');
    signal f_clk : std_logic;
    signal delay_cnt : integer range 0 to 7 := 0;

    -- 保留你原本所有的訊號名稱
    signal sl_state, sr_state, p_state : t_state;
    signal sl_led, sr_led, p_led       : STD_LOGIC_VECTOR(7 downto 0);
    signal sl_dir, sr_dir, p_dir       : STD_LOGIC;
    signal l_state, r_state             : t_state;
    signal l_led, r_led                 : STD_LOGIC_VECTOR(7 downto 0);

begin

    o_led <= led;

    -- 1. 標籤：proc_divider (與訊號名不同即可)
    proc_divider: process(i_clk, i_rst)
    begin
        if i_rst = '1' then cnt <= (others => '0');
        elsif rising_edge(i_clk) then cnt <= cnt + 1;
        end if;
    end process;
    f_clk <= cnt(bits-1);

    -- 2. 標籤：proc_serveL
    proc_serveL: process(i_btnL)
    begin
        sl_state <= serve_L; sl_led <= "10000000"; sl_dir <= '0';
        if i_btnL = '1' then
            sl_state <= play; sl_led <= "01000000"; sl_dir <= '0';
        end if;
    end process;

    -- 3. 標籤：proc_serveR
    proc_serveR: process(i_btnR)
    begin
        sr_state <= serve_R; sr_led <= "00000001"; sr_dir <= '1';
        if i_btnR = '1' then
            sr_state <= play; sr_led <= "00000010"; sr_dir <= '1';
        end if;
    end process;

    -- 4. 標籤：proc_play (加入提早按鍵處分)
    proc_play: process(state, led, dir, i_btnL, i_btnR)
    begin
        p_state <= play; p_led <= led; p_dir <= dir;
        
        -- 提早按鍵判定：球未到邊界卻按鍵，判定為失誤
        if (led /= "10000000" and i_btnL = '1') or (led /= "00000001" and i_btnR = '1') then
            p_state <= show_score;
            -- 誰亂按，就讓球的「最後方向」指向那一邊，計分邏輯會判對方得分
            if i_btnL = '1' then p_dir <= '1'; else p_dir <= '0'; end if;

        elsif led = "10000000" and i_btnL = '0' then 
            p_state <= show_score;
        elsif led = "00000001" and i_btnR = '0' then 
            p_state <= show_score;
        else
            if led = "10000000" and i_btnL = '1' then 
                p_led <= "01000000"; p_dir <= '0';
            elsif led = "00000001" and i_btnR = '1' then 
                p_led <= "00000010"; p_dir <= '1';
            else
                if dir = '0' then p_led <= '0' & led(7 downto 1);
                else               p_led <= led(6 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;

    -- 5. 標籤：proc_winL
    proc_winL: process(sc_L, sc_R)
    begin
        l_state <= win_L; l_led <= sc_L & sc_R; 
    end process;

    -- 6. 標籤：proc_winR
    proc_winR: process(sc_L, sc_R)
    begin
        r_state <= win_R; r_led <= sc_L & sc_R; 
    end process;

    -- 7. 標籤：proc_fsm
    proc_fsm: process(f_clk, i_rst)
    begin
        if i_rst = '1' then
            state <= serve_L;
        elsif rising_edge(f_clk) then
            case state is
                when serve_L => state <= sl_state;
                when serve_R => state <= sr_state;
                when play =>    state <= p_state;
                when show_score =>
                    if delay_cnt = 3 then
                        if sc_L = "1111" then state <= win_L;
                        elsif sc_R = "1111" then state <= win_R;
                        else
                            if dir = '0' then state <= serve_L; else state <= serve_R; end if;
                        end if;
                    end if;
                when others =>  state <= state;
            end case;
        end if;
    end process;

    -- 8. 標籤：proc_led
    proc_led: process(f_clk, i_rst)
    begin
        if i_rst = '1' then led <= "10000000";
        elsif rising_edge(f_clk) then
            case state is
                when serve_L => led <= sl_led;
                when serve_R => led <= sr_led;
                when play    => led <= p_led;
                when show_score =>
                    led <= sc_L & sc_R;
                    if delay_cnt = 3 and sc_L /= "1111" and sc_R /= "1111" then
                        if dir = '0' then led <= "10000000"; else led <= "00000001"; end if;
                    end if;
                when others => led <= sc_L & sc_R;
            end case;
        end if;
    end process;

    -- 9. 標籤：proc_dir
    proc_dir: process(f_clk, i_rst)
    begin
        if i_rst = '1' then dir <= '0';
        elsif rising_edge(f_clk) then
            case state is
                when serve_L => dir <= sl_dir;
                when serve_R => dir <= sr_dir;
                when play    => dir <= p_dir;
                when show_score =>
                    if delay_cnt = 3 then
                        if dir = '0' then dir <= '0'; else dir <= '1'; end if;
                    end if;
                when others => null;
            end case;
        end if;
    end process;

    -- 10. 標籤：proc_scL
    proc_scL: process(f_clk, i_rst)
    begin
        if i_rst = '1' then sc_L <= "0000";
        elsif rising_edge(f_clk) then
            if state = play and p_state = show_score and dir = '0' then
                sc_L <= sc_L + 1;
            end if;
        end if;
    end process;

    -- 11. 標籤：proc_scR
    proc_scR: process(f_clk, i_rst)
    begin
        if i_rst = '1' then sc_R <= "0000";
        elsif rising_edge(f_clk) then
            if state = play and p_state = show_score and dir = '1' then
                sc_R <= sc_R + 1;
            end if;
        end if;
    end process;

    -- 12. 標籤：proc_delay
    proc_delay: process(f_clk, i_rst)
    begin
        if i_rst = '1' then delay_cnt <= 0;
        elsif rising_edge(f_clk) then
            if state = show_score then delay_cnt <= delay_cnt + 1;
            else                       delay_cnt <= 0;
            end if;
        end if;
    end process;

end Behavioral;