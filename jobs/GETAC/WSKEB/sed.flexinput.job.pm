#!/usr/bin/perl
#
# Override the job specific configurations
#

#
# The number of CPUs per node
# must be specified
#
$PPN = 32;

#
# The number of processors needed for this job
# must be specified
#
$NUM_PROCS = 64;

#
# MOAB/TORQUE, plus various RTFDDA monitor scripts, will use this
# Email recipient (REQUIRED for group accounts!!! DEFAULT is login-username)
#
$EMAIL_RECIPIENT = "becky\@ucar.edu,fisherh\@ucar.edu,jshaw\@ucar.edu,hsoh\@ucar.edu,prestop\@ucar.edu,sheu\@ucar.edu,scott.f.halvorson.civ\@mail.mil";

# If this is a model job running over a range, then $RANGE=rangeId
# If this is a model job running over some other location, then $RANGE=GRM
# Defaults to GRM
#
$RANGE = "ATC";

#
# The number of domains
# If $NUM_DOMS < 4, then init.pl will set D4_start = 44640 ("never" start domain 4)
# Must be specifed
#
$NUM_DOMS  = 4;

#
# Forecast length in hours for D4
# Defaults to 0
#
$D4_LENGTH = 120;

#
# The time when to start processing domain 4 (in min)
# Defaults to 0
#
$D4_start = 0;

#
# 1 - this job can only cold-start from 00Z and 12Z;
# 0 - this job can cold-start from nowhour
# COLD_0012 will be set to 0, if CYC_INT > 3
# Defaults to 0
#
$COLD_0012 = 1;

#
# Forecast length in hours from the current hour
# In order to run final analysis only, set FCST_LENGTH to 0
#
$FCST_LENGTH = 120;

#
# The parent directory for the cycle output directory
# Important: Mind the "N" in /raidN
#
# Defaults to /data/cycles. "/raidN/$ENV{LOGNAME}/cycles" from flexinput.pl
#
$RUNDIR_ROOT =  "SEDBASEDIR/$ENV{LOGNAME}/cycles";

#
# Path to mpiexec (PBS mode)  or mpirun (INTER mode)  command
# Defaults to /opt/mpich/bin
#
$MPICMD = "SEDMPICMDBINDIR";

#
# Path to GMT_BIN if not in /opt/GMT
# Defaults to /opt/GMT/bin
#
$GMT_BIN = "SEDBASEDIR/$ENV{LOGNAME}/opt/gmt-4.5.15/bin";

########### END: Most commonly changed parameters ####################

1;
