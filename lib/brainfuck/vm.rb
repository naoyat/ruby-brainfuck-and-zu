module Brainfuck

  def self.VM
    BrainfuckVM.new
  end

  class BrainfuckVM
    def initialize()
      @st = nil
      @ix = 0
      @insts = nil
      @wrap_around = true
    end
    attr_reader :wrap_around

    def load(code)
      @insts, len = compile(code)
    end

    def run
      return unless @insts

      @stop = false
      @st = Array.new
      @ix = 0
      @insts.each{|inst| exec(inst)}
    end

    def list
      list0(@insts) if @insts
    end

    private
    def exec(inst)
      return if @stop

      case inst[0]
      when :while
        subs = inst[1]
        while curr > 0 do
          subs.each{|sub| exec sub}
        end
      when :write
        # write
        printf("%c", curr)
      when :read
        # read
        begin
          c = 0
          while c < 32
            c = STDIN.getc
          end
          set c
        rescue
          @stop = true
        end
      when :move
        @ix += inst[1] # move inst[1]
      when :aug
        set(curr + inst[1]) # aug inst[1]
      when :set
        set inst[1]
      when :show_status
        printf(" :: ix = %d\n", @ix)
        print  " ::  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19\n ::"
        (0..9).each{|i| print @st[i] ? sprintf(" %2x", @st[i]) : "  -" }
        printf(" ")
        (10..19).each{|i| print @st[i] ? sprintf(" %2x", @st[i]) : "  -" }
        printf("\n")
      end
    end

    def list0(insts,indent="")
      insts.each{|inst| list1(inst,indent)}
    end

    def list1(inst,indent="")
      case inst[0]
      when :while
        subs = inst[1]
        print "#{indent}while (st[ix]) {\n"
        list0(subs,indent + "  ")
        print "#{indent}}\n"
      when :write
        print "#{indent}putchar(st[ix])\n"
      when :read
        print "#{indent}st[ix] = getchar()\n"
      when :move
        if inst[1] > 0
          printf("#{indent}ix += %d\n", inst[1])
        else
          printf("#{indent}ix -= %d\n", -inst[1])
        end
      when :aug
        if inst[1] > 0
          printf("#{indent}st[ix] += %d\n", inst[1])
        else
          printf("#{indent}st[ix] -= %d\n", -inst[1])
        end
      when :set
        printf("#{indent}st[ix] = %d\n", inst[1])
      when :show_status
        # do nothing
      end
    end

    def compile(code)
      return nil unless code and code.length > 0

      insts = Array.new

      i = 0
      code_len = code.length
      while i < code_len do
        a = code[i]
        case a
        when 0x5b # [
          if (code[i+1,2] == "-]") # [-]
            insts.push [ :set, 0 ] # lambda{ set 0 }
            i += 3
          else
            subs, len = compile(code[i+1 .. -1]) # [ の次の文字から先（ ] が現れるまで）をコンパイル
            insts.push [ :while, subs ] if subs.size > 0 # subs
            i += 1 + len + 1
          end
        when 0x5d # ]
          return [ insts, i ]
        when 0x2e # .
          insts.push [ :write ] # lambda{ write }
          i += 1
        when 0x2c # ,
          insts.push [ :read ] # lambda{ read }
          i += 1
        when 0x2b, 0x2d # + -
          matched = /[-+]*/.match(code[i .. -1]).to_a[0]
          diff = 0
          matched.length.times{|j|
            if matched[j] == 0x2b # "+"
              diff += 1
            else
              diff -= 1
            end
          }
          insts.push [ :aug, diff ] # eval("lambda{ aug #{diff} }")
          i += matched.length
        when 0x3c, 0x3e # < >
          matched = /[<>]*/.match(code[i .. -1]).to_a[0]
          diff = 0
          matched.length.times{|j|
            if matched[j] == 0x3c # "<"
              diff -= 1
            else
              diff += 1
            end
          }
          insts.push [ :move, diff ] # eval("lambda{ move #{diff} }")
          i += matched.length
        when 0x40 # @
          insts.push [ :show_status ] # for debug
          i += 1
        else
          # do nothing
          i += 1
        end
      end
      return [ insts, i ]
    end

    private
    def curr
      @st[@ix] ||= 0
    end
    def set(value)
      unless @wrap_around
        print "!! value = #{value}\n" unless 0 <= value and value < 256
      end
      @st[@ix] = value % 256
    end
  end

end
