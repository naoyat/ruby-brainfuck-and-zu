#!/usr/bin/env ruby
#
# this is a test script for naoya_t
#
$LOAD_PATH << File.join(File.dirname(__FILE__), "lib/")
require "brainfuck"

wr = Brainfuck.writer
wr.debug_mode = false
code = ""
#code = wr.say("hello.")
#code += wr.say("hello.")

#code += wr.write_uint8(200)
#code += wr.write_char(0x41)
#code += wr.write_string("\n")

#code += wr.set_uint8_at(30,5)
#code += wr.mul_uint8(7)
#code += wr.write_byte_as_uint8(30)
#code += wr.write_string("\n")

code += wr.set_uint8_at(30,50) + wr.set_uint8_at(32,6)
code += wr.move_to(30) + wr.div_byte(32)
code += wr.write_byte_as_uint8(30) + wr.write_string(" / ") +
  wr.write_byte_as_uint8(32) + wr.write_string(" = ") +
  wr.write_byte_as_uint8(12) + wr.write_string(" ... ") +
  wr.write_byte_as_uint8(14) + wr.write_string("\n")

code += wr.set_uint8_at(30,6) #wr.set_uint8_at(32,6)

code += wr.write_byte_as_uint8(30) + wr.write_string(" / 2 = ") 
code += wr.move_to(30) + wr.div_uint8(2) +
  wr.write_byte_as_uint8(12) + wr.write_string(" ... ") +
  wr.write_byte_as_uint8(14) + wr.write_string("\n")

#256.times{|i| code += wr.write_uint8(i) + wr.write_char(0x20) }

#code += wr.write_char(0x0d)

#table = Array.new
#table[1] = 'ask "valid?", 3, 5'
#table[3] = 'say "no."'
#table[5] = 'say "yes."'
#code += wr.node_switch(table)

#code += wr.say("goodbye!")

#TMP_ADDR = 30
#code += wr.set_uint8_at(TMP_ADDR, 5) + wr.mul_uint8(7) + wr.write_curr_as_uint8

#print "code.length = #{code.length}\n"
#print code
#exit

vm = Brainfuck.VM
vm.load(code)
vm.run
