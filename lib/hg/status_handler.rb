#!/usr/bin/env ruby

# relative include
$:.unshift File.join(File.dirname(__FILE__))
require 'common.rb'

if ARGV.length > 0
  # Let the usual handler take care of it.
  exit
end

@project_root = hg_root
@hg_status = `\hg status 2> /dev/null`

@changes = @hg_status.split("\n")
# Exit if too many changes
exit if @changes.size > ENV["hs_max_changes"].to_i

@output_files = []

# Counter for env variables
@e = 0

if @hg_status == ""
  puts "No changes (working directory clean)"
  exit
end

# Index modification states
max_len = ("[%d]" % @changes.length).length
@changes.each do |change|
  colored =
    case change[0, 1]
    when 'M'; change.bold
    when 'A'; change.green
    when 'R'; change.red
    when '!'; change.white.underline
    when '?'; change.blue.underline
    else; ''
    end

  @output_files.push(change[2..-1])
  @e += 1
  num = "%#{max_len}s" % ("[%d]" % @e)
  puts "%s %s" % [ num.white, colored ]
end

print "@@filelist@@::"
puts @output_files.map {|f|
  # If file starts with a '~', treat it as a relative path.
  # This is important when dealing with symlinks
  f.start_with?("~") ? f.sub(/~/, '') : File.join(@project_root, f)
}.join("|")
