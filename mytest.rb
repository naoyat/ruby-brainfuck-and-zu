#!/usr/bin/env ruby
$LOAD_PATH << File.join(File.dirname(__FILE__), "lib/")
require "brainfuck"

wr = Brainfuck.writer

code = wr.say("hello.")

#256.times{|i| code += wr.write_uint8(i) + wr.write_char(0x20) }

code += wr.write_char(0x0d)

table = Array.new
table[1] = 'ask "valid?", 3, 5'
table[3] = 'say "no."'
table[5] = 'say "yes."'
code += wr.node_switch(table)

code += wr.say("goodbye!")

vm = Brainfuck.VM
vm.load(code)
vm.run

