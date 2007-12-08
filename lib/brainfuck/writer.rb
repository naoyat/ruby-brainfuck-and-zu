class String
  def optimize
    begin
      last_length = self.length
      self.gsub!(/<>/,"") ; self.gsub!(/></,"")
    end while self.length < last_length
    self.sub!(/[-+<>,]*\Z/, "")
  end
  def fold(per)
    lines = ((length + (per-1)) / per).to_i
    s = ""
    (lines - 1).times{|l|
      s += self[per*l .. per*l + (per-1)] + "\n"
    }
    s += self[per*(lines-1) .. -1] + "\n" if per*(lines-1) < length
    s
  end
end

module Brainfuck

  def self.writer
    BrainfuckWriter.new
  end

  class BrainfuckWriter
    def initialize
      @_st = Array.new
      @_ix = 0

      @wrap_around = false
    end
    attr_reader :wrap_around

    I_NODE     = 0
    I_NODE_TMP = 1
    I_TMP_SPACE = 2
    I_TMP_PUT   = 3 # +2 ; ʸ�����ɽ����������Υץ�����ͭ���ʤ褦��
    I_TMP_COPY = 5
    I_TMP_ZNZ  = 6
    I_TMP_EQ   = 7
    I_TMP_ADD  = I_TMP_SUB = 8
    I_FLAG     = 9
    I_FLAG_AND = I_FLAG_OR = I_FLAG_NOT  = 10
    I_FLAG_BUP = 11

    I_TMP_YN   = 12 # +3

    K_         = 15 # +2
    K100       = 17 ; K10 = 18 ; K1 = 19

#   TMP        = 19
    VAR_BASE   = 20

    private
    # st[ix] ���ͤ�����
    def _curr
      @_st[@_ix] ||= 0
    end
    # set[ix] = value
    def _set(value)
      if @wrap_around
        @_st[@_ix] = value % 256
      else
        @_st[@_ix] = value
      end
    end

    def var_ofs(ch)
      VAR_BASE + (ch - 0x61)*2
    end

    # ���ܣ�̿��
    public
    def bf_fwd  ; ">" ; end  # ix++
    def bf_back ; "<" ; end  # ix--
    def bf_incr ; _set(_curr + 1) ; "+" ; end  # st[ix]++  - @_st[@_ix]���������Τ�aug()��Ƥ�
    def bf_decr ; _set(_curr - 1) ; "-" ; end  # st[ix]--  - @_st[@_ix]���������Τ�aug()��Ƥ�
    private  # while_wend �� loop{...} �ޤ��� loop_at(k){...} ��Ȥ�
    def bf_while ; "[" ; end # while (st[ix]) {
    def bf_wend  ; "]" ; end # }
    public
    def bf_write ; "." ; end # putchar(st[ix])
    def bf_read  ; "," ; end # st[ix] = getchar()

    # ����äȳ�ĥ̿��
    # ���а�ư: ix += d
    def move(d)
      # ix += d
      @_ix += d
      if d > 0
        ">"*d
      elsif d < 0
        "<"*(-d)
      else
        ""
      end
    end
    # ���а�ư: ix = pos
    def move_to(pos)
      return "" if pos == @_ix
      move(pos - @_ix)
    end

    # �쥸�����ͤ�����
    private
    def pm(d)
      # st[ix] += d
      # ���̤ˤ� add_uint8(d) �ޤ��� sub_uint8(d) �����Ѥ���褦��
      if d > 0
        "+"*d
      elsif d < 0
        "-"*(-d)
      else
        ""
      end
    end

    public
    # while (st[ix]) { ...content... }
    def bf_loop(&b)
      "[" + b.call + "]"
    end
    def loop_at(k,&b)
      move_to(k) + "[" + b.call + move_to(k) + "]"
    end
    def do_once_if(flag_pos,&b)
      move_to(flag_pos) + "[" + b.call + clr_at(flag_pos) + "]"
    end

    # st[ix] = 0
    def clr
      _set 0
      "[-]"
    end

    def save_ix(&b)
      ix_keep = @_ix
      b.call + move_to(ix_keep)
    end

    #
    # �Х��ȱ黻 �� st[ ] �γƥ����ΰ�򤳤��Ǥϡ֥Х��ȡפȸƤ�Ǥ���
    #
    # st[src_pos] �����Ƥ� st[dest_pos] �˥��ԡ���
    # st[src_pos] �����Ƥ��ݻ�����롣
    def copy_byte(dest_pos, src_pos)
      return "" if dest_pos == src_pos

      save_ix {
        clr_at(dest_pos) + clr_at(I_TMP_COPY) + 
        repeat(src_pos) { incr_at(dest_pos) + incr_at(I_TMP_COPY) } +
        repeat(I_TMP_COPY) { incr_at(src_pos) }
      }
    end

    # st[ix] += st[k]
    def add_byte(k)
      ix_keep = @_ix
      save_ix {
        copy_byte(I_TMP_ADD, k) +
        repeat(I_TMP_ADD) { incr_at(ix_keep) }
      }
    end
    # st[ix] -= st[k]
    def sub_byte(k)
      ix_keep = @_ix
      save_ix {
        copy_byte(I_TMP_SUB, k) +
        repeat(I_TMP_SUB) { decr_at(ix_keep) }
      }
    end

    #
    # uint8 - ���ʤ�8�ӥå������黻
    #
    def set_uint8(val)
      # st[ix] = val
      clr + add_uint8(val)
    end

    def add_uint8(val)
      # st[ix] += val
      if val == 0
        return ""
      elsif val < 0
        sign = -1
        val = -val
      else
        sign = 1
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
        bf = bf_fwd + "+"*a + bf_loop{ bf_back + pm(sign * b) + bf_fwd + "-" } + bf_back + pm(sign * c)
      else
        bf = pm(sign * val)
      end
      _set(_curr + sign * val)
      bf
    end

    def sub_uint8(val) ; add_uint8(-val) ; end

    # st[ix] *= val
    def mul_uint8(val)
      clr_at(result)
      [
       
      ]
    end
    # st[ix] /= val, I_MOD = mod
    def div_uint8(val)
    end
#    # st[ix] %= val
#    def mod_uint8(val)
#    end

    # boolean
    # st[ix] &= st[k]
    def and_bool(k)
      save_ix {
        if_zero_at(k) { clr_at(@_ix) }
      }
    end
    # st[ix] |= st[k]
    def or_bool(k)
      save_ix {
        if_nonzero_at(k) { copy_byte(@_ix,k) }
      }
    end
    # st[ix] = not st[k]
    def bool_not(k)
      save_ix {
        copy_byte(I_FLAG_NOT, I_FLAG) +
        set_uint8_at(I_FLAG,1) + sub_byte(I_FLAG_NOT)
      }
    end

    # ***_at(pos) - ��ix��pos��α���
    def incr_at(pos) ; move_to(pos) + bf_incr ; end
    def decr_at(pos) ; move_to(pos) + bf_decr ; end
    def read_at(pos) ; move_to(pos) + bf_read ; end
    def clr_at(pos)  ; move_to(pos) + clr ; end
    def set_uint8_at(pos,val) ; move_to(pos) + set_uint8(val) ; end
    def add_uint8_at(pos,val) ; move_to(pos) + add_uint8(val) ; end
    def sub_uint8_at(pos,val) ; move_to(pos) + sub_uint8(val) ; end
    def set_flag_at(pos) ; set_uint8_at(pos,1) ; end
    def reset_flag_at(pos) ; clr_at(pos) ; end

    # �֥�å�
    def if_nonzero_at(pos, &b)
      # st[pos]�� 0 �Ǥʤ����Τߥ֥�å������Ƥ�¹ԡ�
      # st[pos]���ͤ��ݻ�����롣
      # bool�ͤȤ狼�äƤ�����ϼ���repeat��Ȥ��Ȥ褤��

#      loop_at(pos) { b.call + clr_at(pos) }
      save_ix {
        move_to(pos) + check_if_nonzero + do_once_if(I_FLAG,&b)
      }
    end
    def repeat(count_pos, &b)
      # st[count_pos]�˻��ꤵ�줿��������֥�å������Ƥ�¹�
      loop_at(count_pos) { b.call + decr_at(count_pos) }
    end

    # test�ϡ������Ǥ�test�ǻϤޤ�̾�����դ��ʤ�
    def check_if_zero
      # st[ix] �����Ƥ� 0 ���ɤ����� I_FLAG �˥��åȤ���
      copy_byte(I_TMP_ZNZ, @_ix) +
        set_flag_at(I_FLAG) +
        do_once_if(I_TMP_ZNZ) { decr_at(I_FLAG) } +
#       if_nonzero_at(I_TMP_ZNZ) { decr_at(I_FLAG) } +
        move_to(I_FLAG)
      # ix = I_FLAG�����
    end
    def check_if_nonzero
      # st[ix] �����Ƥ� 0 �Ǥʤ����ɤ����� I_FLAG �˥��åȤ���
      copy_byte(I_TMP_ZNZ, @_ix) +
        reset_flag_at(I_FLAG) +
        do_once_if(I_TMP_ZNZ) { incr_at(I_FLAG) } +
#       if_nonzero_at(I_TMP_ZNZ) { incr_at(I_FLAG) } +
        move_to(I_FLAG)
      # ix = I_FLAG�����
    end
    def check_if_n(n)
      # st[ix] �����Ƥ� n �����������ɤ����� I_FLAG �˥��åȤ���
      sub_uint8(n) + check_if_zero + add_uint8(n)
    end

    # i/o
    def write_char(c)
      # ��ʸ��ɽ�����롣����c�ϥ����ɡ�
      save_ix {
        set_uint8_at(I_TMP_PUT,c) + bf_write
      }
    end
    def write_string(s)
      return "" unless s and s.length > 0

      has_space = (s =~ / /)

      save_ix {
        bf = move_to(I_TMP_PUT) + "<[-]>[-]"  # st[I_TMP_PUT-1] = st[I_TMP_PUT] = 0
        last_putchar_code = 0

        if has_space
          bf += ">++++++++[<++++<++++>>-]<" # st[I_TMP_PUT] = st[I_TMP_PUT-1] = 0x20
          # bf_next()
          @_ix = I_TMP_PUT #+1
          last_putchar_code = 32
        end
        s.length.times do |i|
          c = s[i]
          if c == 0x20
            bf += bf_back if @_ix == I_TMP_PUT
            bf += bf_write
            @_ix = I_TMP_SPACE
          else
            bf += bf_fwd if has_space and @_ix == I_TMP_SPACE
            bf += add_uint8(c - last_putchar_code) + bf_write
            last_putchar_code = c
            @_ix = I_TMP_PUT
          end
        end
        bf
      }
    end
    def write_uint8(i)
      save_ix {
        set_uint8_at(I_TMP_PUT,i) + write_curr_as_uint8
      }
    end

    def write_curr_as_uint8
#      save_ix {
        # st[K_] = k
        # st[K100] = st[K10] = st[K] = 10
      copy_byte(K_, @_ix) +
        set_uint8_at(K1, 10) + set_uint8_at(K10, 10) + set_uint8_at(K100, 10) +
        loop_at(K_) { #  if k
          decr_at(K_) +  # K_ -= 1
          decr_at(K1) +  # K1 -= 1
          if_zero_at(K1) {  # if K1 == 0
            add_uint8_at(K1,10) + decr_at(K10) +  # K1 += 10, K10 -= 1
            if_zero_at(K10) {  # if K10 == 0
              add_uint8_at(K10,10) + decr_at(K100)   # K10 += 10, K100 -= 1
            }
          }
        } +
        # �����ޤǤǡ�st[K1],st[K10],st[K100]�ˤ�
        # k��1�ΰ̡�10�ΰ̡�100�ΰ̤��ͤ�10����������������줾������
        # eg. k=123�ʤ� st[K1]=7, st[K10]=8, st[K100]=9
        reset_flag_at(I_FLAG_BUP) +

        # print (at most 3) digit(s)
        set_uint8_at(K_,10) + sub_byte(K100) +  # K_ = 10 - K100
        if_nonzero_at(K_) {
          add_uint8_at(K_,0x30) + bf_write() +
          set_flag_at(I_FLAG_BUP)
        } +

        set_uint8_at(K_,10) + sub_byte(K10) +  # K_ = 10 - K10
        if_nonzero_at(I_FLAG_BUP) {
          if_zero_at(K_) {
            write_char(0x30)
          }
        } +
        if_nonzero_at(K_) {
          add_uint8_at(K_,0x30) + bf_write
        } +

        set_uint8_at(K_,10) + sub_byte(K1) +  # K_ = 10 - K1
        add_uint8_at(K_,0x30) + bf_write
    end

    def if_zero_at(pos,&b)
      # st[pos]=0�ʤ�֥�å������Ƽ¹�
      save_ix {
        move_to(pos) + check_if_zero + do_once_if(I_FLAG,&b) #if_nonzero_at(I_FLAG,&b)
      }
    end

    def yn_inkey
      # y �� n �����Ϥ����ޤ����ϥ롼�ס�
      # I_TMP_YN �˷�̤����롣��y�ʤ�1,n�ʤ�0��
      # ���η�̤� I_FLAG �ˤ⥳�ԡ�����롣
      y_or_n    = I_TMP_YN   # 1:y 0:n  ==> copied to I_FLAG
      loop_flag = I_TMP_YN+1 # 1:[^yn] 0:[yn]
      inkey     = I_TMP_YN+2 # inkey

      save_ix {
        reset_flag_at(y_or_n) + set_flag_at(loop_flag) +
        loop_at(loop_flag) {
             read_at(inkey) + sub_uint8(0x6e) +  # 0x6e = 'n'
             if_zero_at(inkey) { reset_flag_at(loop_flag) } + # + clr_at(y_or_n) } +
             move_to(inkey) + sub_uint8(11) +  # 11 = 'y' - 'n'
             if_zero_at(inkey) { reset_flag_at(loop_flag) + set_flag_at(y_or_n) } # +
        } +
        copy_byte(I_FLAG, y_or_n)
      }
    end

    def say(s, next_node=0)
      # ʸ���� s ��ɽ�������Ԥ��롣
      write_string(s + "\n") + set_uint8_at(I_NODE, next_node)
    end

    def ask(s, n_node, y_node)
      # ʸ����ʼ���ʸ��s ��ɽ������y/n �����Ϥ�¥����I_NODE��Ŭ�ڤʥΡ����ֹ�˥��åȤ���
      # n_node ����ʤΤ�Zu�λ��ͤ˹�碌�Ƥ��뤿��
      save_ix {
        write_string(s + " [y/n]\n> ") +
        yn_inkey +
        if_nonzero_at(I_TMP_YN) { set_uint8_at(I_NODE, y_node) } +
        if_zero_at(I_TMP_YN) { set_uint8_at(I_NODE, n_node) }
      }
    end

    def node_switch(table)
      bf = set_flag_at(I_NODE) + "[" + copy_byte(I_NODE_TMP, I_NODE)
      (1..table.size-1).each {|i|
        bf += decr_at(I_NODE_TMP)
        bf += if_zero_at(I_NODE_TMP) { eval(table[i]) } if table[i]
      }
      bf + move_to(I_NODE) + "]"
    end

  end
end
