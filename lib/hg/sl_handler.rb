#!/usr/bin/env ruby

# relative include
$:.unshift File.join(File.dirname(__FILE__))
require 'common.rb'

if ARGV.length > 0
  # Let the usual handler take care of it.
  exit
end

@project_root = hg_root
sha_file = File.join(@project_root, '.hg/.sl_sha')
output_file = File.join(@project_root, '.hg/.sl_output')
output = nil
reflog = File.join(@project_root, '.hg/reflog')
bookmarks = File.join(@project_root, '.hg/bookmarks')
if File.exists?(sha_file) && File.exists?(output_file)
  hash = `shasum #{reflog} #{bookmarks} 2> /dev/null`
  if hash == open(sha_file).read
    output = open(output_file).read
  end
end

if output.nil?
  system("shasum #{reflog} #{bookmarks} > #{sha_file} 2> /dev/null")
  system("hg sl --color always > %s 2> /dev/null" % output_file)
  output = open(output_file).read
end

@output_files = []
@e = 0

prev_num = false
output.split("\n").each do |line|
  if prev_num
    prev_num = false
    puts line
    next
  end

  # Strip out bash control characters
  text = line.gsub %r{\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]}, ''
  num = ""
  prev_num = false
  if m = %r{^[^a-np-zA-Z0-9]*\s+([a-z0-9]{6,})\s+([a-z])+}.match(text)
    @e += 1
    @output_files.push(m[1])
    num = "[%d]" % @e
    prev_num = true
  end

  puts "%s %s" % [line.rstrip, num.white]
end

print "@@filelist@@::"
puts @output_files.join("|")
