#!/usr/bin/env ruby
#
# generates prime.bf  / by naoya_t
#
$LOAD_PATH << File.join(File.dirname(__FILE__), "lib/")
require "brainfuck"

wr = Brainfuck.writer
wr.debug_mode = false
code = ""

N = 30
N_TMP = 31
D = 32
D_TMP = 33
LOOP = 34
LOOP_TMP = 35
IS_PRIME = 36

# N = 2
code += wr.set_uint8_at(N, 2)
# while N
code += wr.loop_at(N) {
  # D = N / 2
  wr.copy_byte(D, N) +
  wr.move_to(D) +
  wr.div_uint8(2) +
  wr.set_flag_at(IS_PRIME) +
  # while LOOP {
  wr.set_flag_at(LOOP) +
  wr.loop_at(LOOP) {
    # LOOP = false if D == 1
    wr.decr_at(D) +
    wr.if_zero_at(D) { wr.reset_flag_at(LOOP) } +
    wr.incr_at(D) +

    wr.copy_byte(LOOP_TMP,LOOP) +
    wr.if_nonzero_at(LOOP_TMP) {
      # N_TMP, D_TMP = N, D
      wr.copy_byte(N_TMP,N) +
      wr.copy_byte(D_TMP,D) +
      # N_TMP / D_TMP
      wr.move_to(N_TMP) +
      wr.div_byte(D_TMP) +
      # IS_PRIME = LOOP = false if mod == 0
      wr.if_zero_at(14) {
        wr.reset_flag_at(IS_PRIME) +
        wr.reset_flag_at(LOOP)
      }
    } +
    # D--
    wr.decr_at(D)
  } +
  # }
  # print N,' ' if IS_PRIME
  wr.if_nonzero_at(IS_PRIME) {
    wr.write_byte_as_uint8(N) +
#    wr.write_char(0x20)
    wr.write_string("\n")
  } +
  # N++
  wr.incr_at(N)
} + wr.write_string("\n")

print code

