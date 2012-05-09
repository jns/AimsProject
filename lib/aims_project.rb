
# AimsProject is an application for visualizing and managing projects for
# the FHI-AIMS package

require "rubygems"
require 'aims'
# require "aims_project"
require 'yaml'

require 'aims_project/project.rb'
require 'aims_project/calculation.rb'

module AimsProject
  # Constants
  STAGED   = "STAGED"
  QUEUED   = "QUEUED"
  RUNNING  = "RUNNING"
  COMPLETE = "COMPLETE"
  CANCELED = "CANCELED"
  
  CALC_STATUS_FILENAME = ".calc_status"
  
end