#!/usr/bin/env ruby

#
# stage_calculation.rb [geometry] [control]
# 
# Author: Joshua Shapiro, 2012
# email: joshua.shapiro@gmail.com
# 
# Generate a set of FHI-AIMS calculations from control and geometry files.
# If the user provides filename on the command line the calculation is generated, 
# otherwise, the user is prompted for filenames.
#

begin
  require 'aims_project'
rescue
  require 'rubygems'
  require 'aims_project'
end


require "curses"
include Curses

def build_calculation(geometry, control)
  begin
    calc = AimsProject::Calculation.create(geometry, control)
  rescue 
    puts $!.message
  end
end

if ARGV.size == 2
  # If the user supplies command line args, then 
  # assume they are the control and geometry files
  geometry = ARGV[0]
  control = ARGV[1]
  build_calculation(geometry, control)
else
  # Otherwise prompt the user for geometry and 
  # control files to use.
  
  geometries = Dir.glob("geometry.*.in")
  controls = Dir.glob("control.*.in")

  if geometries.empty?
    puts "No Geometry Files to choose from."
    exit
  end

  if controls.empty?
    puts "No Control files to choose from."
    exit
  end

  # 
  # Return a subset of the array choices 
  def page_choices(choices, choices_per_page, page)
    offset = page*choices_per_page
    while offset > choices.size
        page = page - 1
        offset = page*choices_per_page
    end
  
    page_choices = {}
    (offset..offset+choices_per_page).each do |i|
      page_choices[i+1] = choices[i] if choices[i]
    end
    page_choices
  end

  def show_choices(window, choices)
    choices.each_pair {|key, val|
      window.addstr("(#{key})  #{val}\n")
    }
  end

  init_screen
  begin
    crmode
    win = Window.new(0, 0, 1,1)
    width = win.maxx
    height = win.maxy
    show_choices(win, page_choices(geometries, height-5, 0))
    win.setpos(height-1, 1)
    win << "Choose a geometry:  "
    win.refresh
    ch = win.getch
  
  ensure
    close_screen
  end
end