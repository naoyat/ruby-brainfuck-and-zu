class String
  def optimize
    begin
      last_length = self.length
      self.gsub!(/<>/,"") ; self.gsub!(/></,"")
    end while self.length < last_length
    self.sub!(/[-+<>,]*\Z/, "")
  end
end

module Brainfuck

  def self.writer
    BrainfuckWriter.new
  end

  class BrainfuckWriter
    def initialize
      @st = Array.new
      @ix = 0
      @wrap_around = false
    end
    attr_reader :wrap_around

    I_NODE     = 0
    I_NODE_TMP = 1
    I_TMP_PUT  = 2 # +3 ; 文字列を表示するだけのプログラムに有利なように
    I_TMP_COPY = 5
    I_TMP_ZNZ  = 6
    I_TMP_EQ   = 7
    I_TMP_ADD  = I_TMP_SUB = 8
    I_FLAG     = 9
    I_FLAG_AND = I_FLAG_OR = I_FLAG_NOT  = 10
    I_FLAG_BUP = 11

    I_TMP_YN   = 12 # +3

    K_         = 15
    K100 = 16 ; K10 = 17 ; K1 = 18

    TMP        = 19
    VAR_BASE   = 20

    private
    def curr
      @st[@ix] ||= 0
    end
    def set(value)
      @st[@ix] = value % 256
    end

    public
    def var_ofs(ch)
      VAR_BASE + (ch - 0x61)*2
    end

    def move(d)
      # ix += d
      @ix += d
      if d > 0
        ">"*d
      elsif d < 0
        "<"*(-d)
      else
        ""
      end
    end
    def move_to(pos) ; move(pos - @ix) ; end
    def fwd ; move(1) ; end
    def back ; move(-1) ; end

    private
    def aug(d)
      # st[ix] += d
      # 一般には add_uint8(d) または sub_uint8(d) を利用するように
      set(curr + d)
      if d > 0
        "+"*d
      elsif d < 0
        "-"*(-d)
      else
        ""
      end
    end

    public
    def incr ; aug(1) ; end
    def decr ; aug(-1) ; end

    def loop(content)
      "[" + content + "]"
    end
    def write
      "."
    end
    def read
      ","
    end

    def clr
      # st[ix] = 0
      set 0
      "[-]"
    end

    # uint8
    def set_uint8(val)
      # st[ix] = val
      clr + add_uint8(val)
    end

    def add_uint8(val)
      # st[ix] += val
      if val == 0
        return ""
      elsif val < 0
        return sub_uint8(-val)
      end

      a = Math::sqrt(val).to_i
      c = val % a
      b = (val - c) / a
      if c > (a/2).to_i
        b += 1
        c -= a
      end
      if a + b + c + 7 < val
        # >+++[<+++>-]<+
        bf = fwd + aug(a) + loop( back + aug(b) + fwd + decr ) + back + aug(c)
      else
        bf = aug(val)
      end
      set(curr + val)
      bf
    end

    def sub_uint8(val)
      # st[ix] -= val
      if val == 0
        return ""
      elsif val < 0
        return add_uint8(-val)
      end

      a = Math::sqrt(val).to_i
      c = val % a
      b = (val - c) / a
      if c > (a/2).to_i
        b += 1
        c -= a
      end
      if a + b + c + 7 < val
        # >+++[<--->-]<-
        bf = fwd + aug(a) + loop( back + aug(-b) + fwd + decr ) + back + aug(-c)
      else
        bf = aug(-val)
      end
      set(curr - val)
      bf
    end

    def copy_byte(dest_pos, src_pos)
      # st[src_pos] の内容を st[dest_pos] にコピー。
      # st[src_pos] の内容は保持される。
      ix_keep = @ix

      clr_at(dest_pos) + clr_at(I_TMP_COPY) + 
        times(src_pos) { incr_at(dest_pos) + incr_at(I_TMP_COPY) } +
        times(I_TMP_COPY) { incr_at(src_pos) } +
        move_to(ix_keep)
    end

    # at
    def incr_at(pos) ; move_to(pos) + incr ; end
    def decr_at(pos) ; move_to(pos) + decr ; end
    def clr_at(pos) ; move_to(pos) + clr ; end
    def read_at(pos) ; move_to(pos) + read ; end
    def set_uint8_at(pos, val) ; move_to(pos) + set_uint8(val) ; end

    def block(flag_pos, &b)
      # st[flag_pos]にフラグが立つている場合のみブロックの内容を実行
      move_to(flag_pos) + loop( b.call + clr_at(flag_pos) )
    end

    def times(count_pos, &b)
      # st[count_pos]に指定された回数だけブロックの内容を実行
      move_to(count_pos) + loop( b.call + decr_at(count_pos) )
    end

    def check_if_zero
      # st[ix] の内容が 0 かどうかを I_FLAG にセットする
      ix_keep = @ix
      copy_byte(I_TMP_ZNZ, @ix) +
        set_uint8_at(I_FLAG, 1) +
        block(I_TMP_ZNZ) { decr_at(I_FLAG) } +
        move_to(ix_keep)
    end
    def check_if_nonzero
      # st[ix] の内容が 0 でないかどうかを I_FLAG にセットする
      ix_keep = @ix
      copy_byte(I_TMP_ZNZ, @ix) +
        clr_at(I_FLAG) +
        block(I_TMP_ZNZ) { incr_at(I_FLAG) } +
        move_to(ix_keep)
    end
    def check_if_n(n)
      # st[ix] の内容が n に等しいかどうかを I_FLAG にセットする
      sub_uint8(n) + check_if_zero + add_uint8(n)
    end

    # i/o
    def putchar(c)
      # １文字表示する。引数cはコード。
      ix_keep = @ix
      set_uint8_at(I_TMP_PUT,c) + write + move_to(ix_keep)
    end
    def puts(s)
      return "" unless s and s.length > 0

      has_space = (s =~ / /)

      ix_keep = @ix
      bf = move_to(I_TMP_PUT)

      bf += "[-]>[-]<"
      last_putchar_code = 0

      if has_space
        bf += ">>++++++++[<++++<++++>>-]<" # st[I_TMP_PUT] = st[I_TMP_PUT+1] = 0x20
        # bf_next()
        @ix = I_TMP_PUT+1
        last_putchar_code = 32
      end
      s.length.times do |i|
        c = s[i]
        if c == 0x20
          bf += back if @ix > I_TMP_PUT
          bf += write
        else
          bf += fwd if has_space and @ix == I_TMP_PUT
          bf += add_uint8(c - last_putchar_code) + write
          last_putchar_code = c
        end
      end
      bf += move_to(ix_keep)
      bf
    end

    def if_at(pos,&b)
      # st[pos]≠0ならブロックの内容実行
      ix_keep = @ix
      move_to(pos) + check_if_nonzero + block(I_FLAG,&b) + move_to(ix_keep)
    end

    def unless_at(pos,&b)
      # st[pos]=0ならブロックの内容実行
      ix_keep = @ix
      move_to(pos) + check_if_zero + block(I_FLAG,&b) + move_to(ix_keep)
    end

    def yn_inkey
      # y か n が入力されるまで入力ループ。
      # I_TMP_YN に結果が入る。（yなら1,nなら0）
      # この結果は I_FLAG にもコピーされる。
      y_or_n    = I_TMP_YN   # 1:y 0:n  ==> copied to I_FLAG
      loop_flag = I_TMP_YN+1 # 1:[^yn] 0:[yn]
      inkey     = I_TMP_YN+2 # inkey

      ix_keep = @ix
      clr_at(y_or_n) +
        set_uint8_at(loop_flag, 1) +
        loop(
             # inkey = getchar() - 'n'
             read_at(inkey) + sub_uint8(0x6e) +
             # if (inkey == 0) { loop_flag = y_or_n = 0 }
             unless_at(inkey) { decr_at(loop_flag) } + # + clr_at(y_or_n) } +
             # inkey -= ('y' - 'n')
             move_to(inkey) + sub_uint8(11) +
             # if (inkey == 0) { loop_flag = 0; y_or_n = 1 }
             unless_at(inkey) { decr_at(loop_flag) + set_uint8_at(y_or_n,1) } +
#             read_at(inkey) +
#             check_if_n(0x6e) + if_at(I_FLAG) { decr_at(loop_flag) } +
#             move_to(inkey) +
#             check_if_n(0x79) + if_at(I_FLAG) { decr_at(loop_flag) + set_uint8_at(y_or_n,1) } +
             move_to(loop_flag)
             ) +
        copy_byte(I_FLAG, y_or_n) +
        move_to(ix_keep)
    end

    def say(s, next_node=0)
      # 文字列 s を表示し改行する。
      puts(s + "\n") + set_uint8_at(I_NODE, next_node)
    end

    def ask(s, n_node, y_node)
      # 文字列（質問文）s を表示し、y/n の入力を促し、I_NODEを適切なノード番号にセットする
      ix_keep = @ix
      puts(s + " [y/n]\n> ") +
        yn_inkey +
        if_at(I_TMP_YN) { set_uint8_at(I_NODE, y_node) } +
        unless_at(I_TMP_YN) { set_uint8_at(I_NODE, n_node) } + move_to(ix_keep)
    end

    def node_switch(table)
      bf = set_uint8_at(I_NODE,1) + "[" +
        copy_byte(I_NODE_TMP, I_NODE)
      (1..table.size-1).each {|i|
        bf += decr_at(I_NODE_TMP)
        bf += unless_at(I_NODE_TMP) { eval(table[i]) } if table[i]
      }
      bf += move_to(I_NODE) + "]"
      bf
    end

  end
end

#wr = ToBrainfuck.writer
#print wr.say("hello")
#print wr.ask("valid?", 3, 5)

#table = Array.new
#table[1] = [:ask, "valid?", 3, 5]
#table[3] = [:say, "yes!"]
#table[5] = [:say, "no!"]
#print wr.node_switch(table)
