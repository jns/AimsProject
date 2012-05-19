
# AimsProject is an application for visualizing and managing projects for
# the FHI-AIMS package

require "rubygems"
require 'aims'
require 'yaml'

require 'aims_project/project.rb'
require 'aims_project/calculation.rb'

# AimsProject is a set of tools for managing and organizing 
# calculations for executaion on high-performance computing clusters.
# It is designed specifically for the FHI-AIMS package published
# by the Fritz-Haber Institute (https://aimsclub.fhi-berlin.mpg.de), 
# but can probably be generatlized to other codes.
#
# Author: Joshua Shapiro (email:joshua.shapiro@gmail.com)
# Copyright: 2012 Joshua Shapiro
# License: TBD
#
# = Why should I use AimsProject?
# Good organization is crucial to obtaining meaningful results with
# the FHI-AIMS package.  Careful testing of convergence 
# across parameters in the control and geometry files easily requires
# dozens of calculations.  The novice and expert user alike can quickly 
# lose track of which calculations are complete, which are still pending,
# which calculations were errors, and which calculations failed or were aborted.
# In this framework, even the most experienced user can and will make mistakes.  
#
# <em>The aim of this tool is to simplify and streamline the calculation 
# pipeline, so the user can focus on the results.</em>
# 
# = Features
# * Automated generation of calculations from control & geometry files.
# * Automated synchronization between a workstation and the compute cluster. 
# * Automated job submission of pending calculations to the queue
# * Status tracking of calculations from creation to completion.
# * Simple organizational structure with human readable metadata. 
#   
# = Planned Features
# * Input file validation (To catch mistakes before submitting to a queue)
# * Geometry input and output visualization
# 
# = Quick Start
# == Installation
#
#    gem install aims_project
#
# == Creating a Project
#
# Type:
#       AimsProject myProject
# 
# This will create the directory structure
#      myProject
#       -> calculations/
#       -> config/
#       -> control/
#       -> geometry/
#       -> Capfile
#       -> myProject.yaml
#
# 
# +calculations+:: Contains one subdirectory for each calculation.
# +config+:: Contains special configuration files for automation.
# +geometry+:: This is where you will place all your geometry files.
# +control+:: This is where you place all your control files.
# +Capfile+:: Location where you customize the interaction with the compute cluster
# +myProject.yaml+:: Human readable metadata related to this project.
#
# == Creating a calculation
#
# Assume you are investigating two atomic configurations _alpha_ and _beta_, and
# you want to calculate them with the _light_ and _tight_ settings. 
# 
# Create the FHI-AIMS formatted input files and name them 
# * +geometry/alpha+
# * +geometry/beta+
# * +control/light+
# * +control/tight+
#
# Now run 
#    > AimsCalc alpha light
#    > AimsCalc beta light
#    > AimsCalc alpha tight
#    > AimsCalc beta tight
#
# This will create four subdirectories inside +calculations/+.
#    > ls calculations/*
#     calculations/alpha.light:
#     calc_status.yaml   control.in       geometry.in
#     
#     calculations/alpha.tight:
#     calc_status.yaml   control.in       geometry.in
#     
#     calculations/beta.light:
#     calc_status.yaml   control.in       geometry.in
#     
#     calculations/beta.tight:
#     calc_status.yaml   control.in       geometry.in
#     
# Notice that each calculation directory has the required +control.in+ and 
# +geometry.in+ file.  These were directly copied from the geometry and control files
# passed to AimsCalc.  *Note* It is possible to embed variables inside the control
# and geometry files, see AimsCalc for more details. Each directory also contains
# a file named +calc_status.yaml+.  This is a metadata file used for tracking
# the history and status of the calculation.  Currently this file looks something like
#    --- !ruby/object:AimsProject::Calculation 
#    control: light
#    geometry: alpha
#    status: STAGED
# 
# 
# Feel free to get more creative with the geometry and control file names.  You should encode
# as much information in the file name as possible, as this will make it easy 
# for you to identify the calculation later.  For example, a geometry file 
# named +alpha2x2_5layers_relaxed+ and a control file named +light_tier1_norelax_6x6x1_lomem+
# will result in a calulation directory named +alpha2x2_5layers_relaxed.light_tier1_norelax_6x6x1_lomem+
#
# == Running a Calculation
# At this point the calculation status is +STAGED+.  To run the calculation, first customize
# the +Capfile+ with details necessary for running FHI-AIMS on the computing cluster. 
# Check this file carefully, this is where you define the name and location of the aims executable, 
# the name of the server, and the method for submitting jobs to the queue.  Once this file 
# is properly configured, the calculations are submitted with one line:
# 
#     cap aims:enqueue
#
# This command invokes custom tasks in +Capistrano+, a 3rd party tool for automated deployment, 
# that will upload the calculations to the server and submit them to the queue.
# 

module AimsProject
  # Constants
  STAGED   = "STAGED"
  QUEUED   = "QUEUED"
  RUNNING  = "RUNNING"
  COMPLETE = "COMPLETE"
  ABORTED  = "ABORTED"
  CANCELED = "CANCELED"
  
  CALCULATION_DIR = "calculations"
  GEOMETRY_DIR = "geometry"
  CONTROL_DIR = "control"
  CALC_STATUS_FILENAME = "calc_status.yaml"
  

end