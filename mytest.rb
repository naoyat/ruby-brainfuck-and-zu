#!/usr/bin/env ruby
#
# this is a test script for naoya_t
#
$LOAD_PATH << File.join(File.dirname(__FILE__), "lib/")
require "brainfuck"

wr = Brainfuck.writer
code = ""
#code = wr.say("hello.")

#256.times{|i| code += wr.write_uint8(i) + wr.write_char(0x20) }

#code += wr.write_char(0x0d)

#table = Array.new
#table[1] = 'ask "valid?", 3, 5'
#table[3] = 'say "no."'
#table[5] = 'say "yes."'
#code += wr.node_switch(table)

#code += wr.say("goodbye!")

TMP_ADDR = 30
code += wr.set_uint8_at(TMP_ADDR, 5) + wr.mul_uint8(7) + wr.write_curr_as_uint8

vm = Brainfuck.VM
vm.load(code)
vm.run

