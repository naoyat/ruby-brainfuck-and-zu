require 'enumerator'

module TextGraph

  def self.parse(str)
    Parser.new(str).parse
  end

  class Graph

    def initialize(cells, links)
      @cells, @links = cells, links
    end
    attr_reader :cells, :links

  end

  class Parser

    def initialize(str)
      @chars = CharMap.new(str)
    end

    def parse
      cells = collect_cells()
      links = find_links(cells)
      Graph.new(cells, links)
    end

    def find_links(cells)
      #[[0,1], [1,3], [3,2], [2,0]]
      collect_chars(?+).map do |x,y|
        #dx, dy, goal = get_direction(x,y)
        #ひどいアルゴリズムだ
        x2, y2 = find_end(x, y, 1, 0, ?>)
        x2, y2 = find_end(x, y,-1, 0, ?<) if x2.nil?
        x2, y2 = find_end(x, y, 0, 1, ?v) if x2.nil?
        x2, y2 = find_end(x, y, 0,-1, ?^) if x2.nil?
        [cell_at(cells,x,y), cell_at(cells,x2,y2)]
      end
    end

    def cell_at(cells, x, y)
      cells.each_with_index{|cell, i|
        if (cell.x ... (cell.x + cell.w)) === x and
           (cell.y ... (cell.y + cell.h)) === y
          return i
        end
      }
      raise ArgumentError, "no cell found at #{x},#{y}"
    end

    def get_direction(x,y)
      raise ArgumentError, "not start" if @chars[x,y] != ?+
      case
      when [?-, ?>].include?(@chars[x+1,y])
        [1, 0, ?>]
      when [?|, ?v].include?(@chars[x,y+1])
        [0, 1, ?v]
      when [?-, ?<].include?(@chars[x-1,y])
        [-1, 0, ?<]
      when [?|, ?^].include?(@chars[x,y-1])
        [0, -1, ?^]
      else
        raise ArgumentError, "can't decide direction"
      end
    end

    def collect_cells
      collect_chars(?*).map{|x,y|
        w, h = is_cell?(x,y)
        if w && h
          Cell.new(x, y, w, h, get_str(x, y, w, h))
        end
      }.compact
    end

    def get_str(x, y, w, h)
      a = []
      (y+1).upto(y+(h-1)-1) do |yy|
        s = ""
        (x+1).upto(x+(w-1)-1) do |xx|
          s << @chars[xx, yy].chr
        end
        a << s 
      end
      a.join("\n")
    end

    def is_cell?(x, y)
      if [?-, ?v, ?+].include?(@chars[x+1, y]) and [?|, ?>, ?+].include?(@chars[x, y+1])
        x2 = find_end(x, y,  1, 0, ?*)[0]
        y2 = find_end(x, y,  0, 1, ?*)[1]
        x3 = find_end(x, y2, 1, 0, ?*)[0]
        y3 = find_end(x2, y, 0, 1, ?*)[1]

        return (x2==x3 && y2==y3) ? [x2-x+1, y2-y+1] : false
      else
        return false
      end
    end

    def find_end(x, y, dx, dy, goal)
      raise ArgumentError, "holiz/vert only" if dx != 0 && dy != 0
      begin
        x += dx
        y += dy
        case @chars[x, y] 
        when goal
          return [x,y] 
        when ?-, ?|, ?+, ?v, ?^, ?>, ?<
          ;
        else
          break
        end
      end while x < @chars.width && y < @chars.height

      return nil
    end

    def collect_chars(char)
      @chars.map{|x,y,c|
        (c == char) ? [x,y] : nil
      }.compact
    end

  end

  class CharMap
    include Enumerable

    def initialize(str)
      @data = partition(str)
      @width  = @data.map{|line| line.size}.max
      @height = @data.size
    end
    attr_reader :width, :height

    def partition(str)
      str.enum_for(:each_line).map{|line|
        line.rstrip.enum_for(:each_byte).to_a
      }
    end

    def [](x,y)
      if (0...@width) === x && (0...@height) === y
        @data[y][x] || ?\s
      else
        nil
      end
    end

    def each_char
      @data.each_with_index do |line, y|
        line.each_with_index do |c, x|
          yield x, y, c
        end
      end
    end
    alias each each_char

  end

  class Cell

    def initialize(x, y, w, h, str)
      raise ArgumentError, "x or y value too small" if x < 0 || y < 0
      raise ArgumentError, "w or h value too small" if w < 2 || h < 2

      @x, @y, @w, @h, @raw_content = x, y, w, h, str
    end
    attr_reader :x, :y, :w, :h, :raw_content

    def content
      @raw_content.strip
    end

    def ==(other)
      @x == other.x && @y == other.y && @w == other.w && @h == other.h &&
        @raw_content == other.raw_content
    end
  end

end

require 'textgraph/version'
