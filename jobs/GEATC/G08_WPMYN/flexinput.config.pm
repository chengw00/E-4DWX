#!/usr/bin/perl
########################## Resource Manager Specifics ##########################

#
# Definition of job wall times
# Moab/Torque will kill the job if it exceeds this time limit
#
# These should be set to near the same length as the RTFDDA "cycle",
# i.e. 3hrs, 6hrs, etc
#
# Defaults to 60 minutes
#

# The MPI job's wall time in seconds
$MPI_WALLTIME = "02:30:00"; # 2.5 hours

# The post-processing job's wall time in seconds
$POST_PROC_WALLTIME = "02:55:00"; # 2.9 hours

# The verification job's wall time in seconds
$VERI_WALLTIME = "02:30:00"; # 2.5 hours

################################# MODIS SST ####################################
#
# Flag to turn on the MODIS SST files
# Default is 0
# USE_MODIS = 1 will allow the model to use the MODIS SST data
$USE_MODIS = 1;

################################# Great Salt Lake SST ##########################
#
# Flag to turn on the Great Salt Lake Surface Temperatures 
# Default is 0
# USE_MODIS = 1 will allow the model to use the MODIS SST data
$USE_GSL = 1;

################################## ICBC ########################################

#
# Pressure Top Level of ICBC data
# Defaults to 100 for 'AVN', 'AVNFTP', 'GFS004', 'NNRP', 'NNRP2'
# otherwise to 50 for 'ETA'
# can be 50mb with gfs3/avn now...
#
$PTOP = 100;

#
# The location directory for the ICBC data files
# Defaults to /data/input/avnftp for AVNFTP
#          to /data/input/gfs3 for GFS003-grib2
#          to /data/input/eta for ETA
#          to /data/input/nam212 for NAM212-grib2
#          to /data/input/avn for AVN
#          to /data/input/gfs4 for GFS004-grib2
#          to /data/input/GFS004 for GFS004
#          to /data/static/NNRP for NNRP
#          to /data/static/NNRP2 for NNRP2
$DATA_ICBC_DIR = $DATADIR."/GEFS";
$DATA_ICBC_DIR2 = $DATA_ICBC_DIR; # always
$BCS = "GEFS"; # "ICBC"
$GEFSMEM = "gep08"; # name of GFS ensemble member; script will set this right

# The following strings will be substituted by the ICBC script:
#   "CYCLE" == model cycle time - usually 00 or 12
#   "FF"    == forecast hour offset - exact number of digits to use is included
#   "CC"    == century
#   "YY"    == year
#   "MM"    == month
#   "DD"    == day
#   "HH"    == hour
#    I.e. "eta.T00Z.AWIP3D00.tm00.07121700";
#    I.e. "2007121712_fh.0003_tl.press_gr.1p0deg.grib2";
# GFS003-grib2
$ICBC_NAME_TEMPLATE = "CCYYMMDDHH_fh.FFFF_".$GEFSMEM."_tl.press_gr.1p0deg.grib2";
$ICBC_NAME_TEMPLATE2 = $ICBC_NAME_TEMPLATE; # always

#
# IC/BC pre-processor perl script to use
#
# A custom pre-processor script must implement the subroutine 'processData()'
#
# defaults to NAM-preprocessor.pl when $BCS = ETA
# defaults to GFS-preprocessor.pl when $BCS = AVNFTP
# defaults to AVN-preprocessor.pl when $BCS = AVN
# defaults to GFS0004-preprocessor.pl when $BCS = GFS004
# defaults to NNRP-preprocessor.pl when $BCS = NNRP
# defaults to NNRP2-preprocessor.pl when $BCS = NNRP2
# otherwise: must be specified
#
$ICBC_PREPROCESSOR = $PERL_FLEX.'/ICBC/GEFS-preprocessor.pl';
$ICBC_NAME_GEFS = "CCYYMMDDHH_fh.FFFF_".$GEFSMEM."_tl.press_gr.1p0deg.grib2";

############################### Observations ###################################

#
# The observation data sets
# 1 - use this data set
# 0 - don't use this data set
#
$DTE = 1;

############################ POST-PROCESSING ###################################

#
# Post-processing: run veri_rtfdda_3hcyc.pl
# 1 - submits the script ${PERL_FLEX}/veri_rtfdda3hcyc_range_wrf.pl
# 0 - doesn't sumbit above script
# Defaults to 0
#
$VERI3HCYC = 0;

#
# Post-processing: Create Gridded Bias correction stats and output files
# 1 - run GriddedBiasCorrection and CorrectForecast
# 0 - doesn't run GriddedBiasCorrection and CorrectForecast
$GBC = 0;

#
# Post-processing: Create Analog Ensemble plots
# Done here instead of postprocs because it is based on previous cycle
# 1 - run Analog Ensemble plots 
# 0 - doesn't run AnEn 
$AnEn = 0;

#
# Are WRF restart files written out and read in per core?
# Note, this requires that variable io_form_restart in WRF namelist
# be set to 102.
#
$RESTART_PER_CORE = 1;

1;
