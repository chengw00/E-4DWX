#!/bin/tcsh
# set echo
###############################################################################
#
# Usage: submitCycleMM.csh <-c cycle_time>
#                          <-i cyc_int>
#                          <-r reservation_id>
#                          <-a project_account>
#                          <-s start_time>
#                          <-W prev_jobID>
#                          <-f env_var_file>
#                          -h
#
# All flags are optional. cycle_time, cyc_int, reservation_id, project_account,
# start_time can be set in flexinput.pl as well and are provided here for
# convenience.
#
# This script does the following:
#  1) Reads in env-vars from the file supplied with the -f option or if -f is
#     not provided, then it reads ./env_vars.csh by default
#  2) executes PERL_FLEX/init.pl, which creates the files
#     "cshrc" and "pre_process_in_donotedit.pl"
#  3) source cshrc
#  4) creates the directories ./tmp/$this_cycle and ./logs/$this_cycle
#     - tmp/$this_cycle will contain the files "cshrc" and "pre_process_in_donotedit.pl",
#       which are input files for the subprocesses
#     - logs/$this_cycle will contain logfiles of each subprocess and the
#       Moab/Torque-job-ids of each subprocess
#  5) submits pre_process_F.pl
#  6) submits #CSH_ARCHIVE/Forecast/RT_L_MM_$MODEL_rtfdda.csh with fcst_id = 1 or 2
#  7) submits rtfdda_postprocess.pl (if turned on)
#  7.1) submits veri_rtfdda_flex_${MODEL}.pl (if turned on)
#  8) submits pre_process_P+FCST.pl (if $FCST_LENGTH > 0)
#  9) submits $CSH_ARCHIVE/Forecast/RT_L_MM_$MODEL_rtfdda.csh
#      with fcst_id = 3 (Prelim+Forecast) (if $FCST_LENGTH > 0)
#  10) submits post_process_clean.pl
#
################################################################################
set argv=`getopt c:i:r:a:s:f:W:h $*`
set cycle = 0
set cyc_int = 0
set res_id = 0
set account = 0
set start = 0
set pre_process_F_wait = ""
set env_var_file = "./env_vars.csh"

set argsstr="$argv"

foreach name ($argv)

  switch ($name)
    case -c:
       set cycle = $2
       breaksw
    case -i:
       set cyc_int = $2
       breaksw
    case -r:
       set res_id = $2
       breaksw
    case -a:
       set account = $2
       breaksw
    case -s:
       set start = $2
       breaksw
    case -W:
       set pre_process_F_wait = "-W depend=afterany:$2"
       breaksw
    case -f:
       set env_var_file = $2
       breaksw
    case -h:
       echo "$0 <-c cycle_time> <-i cyc_int> <-r reservation_id> <-a project_account> <-s start_time> <-W prev_jobId>"
       echo " where  "
       echo "   -c cycle_time:       format is YYYYMMDDhh, will override 'this_cycle' in flexinput.pl"
       echo "   -i cycle_int:        format is integer (hours), will override 'CYC_INT' in flexinput.pl"
       echo "   -r reservation_id:   will override 'RES_NAME' in flexinput.pl"
       echo "   -a project_account:  will override 'ACCOUNT_KEY' in flexinput.pl"
       echo "   -s start_time:       when should Moab run the job, format is YYYYMMDDhhmm.ss,"
       echo "                        will override 'JOB_START_TIME' in flexinput.pl"
       echo "   -W prev_jobId:       will submit the pre_process_F-job with '-W depend=afterany:prev_jobId'",
       echo "                        i.e., pre_process_F won't start until successful termination of prev_JobId"
       echo "   -f env_var_file:  e.g. /raidN/Logname/GMODJOBS/JOBID/scripts/env_vars.csh, defaults to ./env_vars.csh"
       echo "All flags are optional."
       echo " "
       exit
       breaksw
    case --:
       breaksw
  endsw

  shift
end

echo "Using env-vars file: ${env_var_file}"
source ${env_var_file}

if (! -e ${GSJOBDIR}/tmp ) then
  mkdir ${GSJOBDIR}/tmp
endif
if (! -e ${GSJOBDIR}/logs ) then
  mkdir ${GSJOBDIR}/logs
endif

# run $PERL_FLEX/init.pl to set all variables, make necessary input files, such
# as ./tmp/pre_process_in_donotedit.pl and ./tmp/cshrc and needed directories

module load python/2.7

echo "Calling ${PERL_FLEX}/init.pl with '$argsstr'"
echo "flexinput file is $FLEXINPUT"

${PERL_FLEX}/init.pl $argsstr >& ${GSJOBDIR}/logs/out_flexinput.log

if ($? != 0) then
 echo Initialization failed ..... EXITING
 echo Please check ${GSJOBDIR}/logs/out_flexinput.log
 exit -1
endif

# source the env-file $GSJOBDIR/tmp/cshrc
echo sourcing ${GSJOBDIR}/tmp/cshrc
source ${GSJOBDIR}/tmp/cshrc

# make tmp/$this_cycle for temporary input files
if (! -e ${GSJOBDIR}/tmp/${this_cycle}) then
  mkdir ${GSJOBDIR}/tmp/${this_cycle}
else
  rm -rf ${GSJOBDIR}/tmp/${this_cycle}/*
endif

# make logs/$this_cycle for this cycle's log files
if (! -e ${GSJOBDIR}/logs/${this_cycle} ) then
  mkdir ${GSJOBDIR}/logs/${this_cycle}
else
  rm -rf ${GSJOBDIR}/logs/${this_cycle}/*
endif


### A string that shows up in qstat -aw for better debugging
set tmp_label = `echo ${this_cycle} | cut -c7-10`
set cycle_label = `echo ${GSJOBID} | cut -c3-7`_$tmp_label
echo "cycle label $cycle_label"

# move cshrc and pre_process_in_donotedit.pl to tmp/$this_cycle
mv ${GSJOBDIR}/tmp/cshrc ${GSJOBDIR}/tmp/${this_cycle}
mv ${GSJOBDIR}/tmp/pre_process_in_donotedit.pl ${GSJOBDIR}/tmp/${this_cycle}

setenv TMPDIR ${GSJOBDIR}/tmp/${this_cycle}
setenv LOGDIR ${GSJOBDIR}/logs/${this_cycle}
#QUEUE, DSP and ACCOUNT_KEY should be/are defined in env_vars.csh
echo "ACCOUNT_KEY : $ACCOUNT_KEY"
echo "QUEUE : $QUEUE"
echo "DSP : $DSP"

#################### create a machine file for interactive job #################

if ($BATCH_SYSTEM == "INTER") then

  ${PERL_FLEX}/machinefile.pl -i ${GSJOBDIR}/nodes_available -m $NUM_PROCS -n $PPN -o ${GSJOBDIR}/machinefile >>! ${GSJOBDIR}/logs/out_flexinput.log

# Check machine file
  if (! -e ${GSJOBDIR}/machinefile) then
     echo perl/machinefile.pl failed ..... EXITING
     echo Please check ${GSJOBDIR}/logs/out_flexinput.log
     exit -1
  else
# Grab head node
     if (! -z ${GSJOBDIR}/machinefile) then
         set nodes = `cat ${GSJOBDIR}/machinefile`
         set HeadNode = $nodes[1]
     else
         echo ${GSJOBDIR}/machinefile is empty ..... EXITING
         echo Please check ${GSJOBDIR}/logs/out_flexinput.log
         exit -1
     endif
  endif
endif

set job_err_log_name = ${LOGDIR}/job_submit.err

#################### submit the pre-processing-F script ########################
echo ""
if ($DEBUG) then
  echo "submitting ${PERL_FLEX}/pre_process_F.pl with:"
  echo " -N ${this_cycle}_preF"
  echo " ${JOB_START} (optional: when should the job start)"
  echo " -l ${RESOURCE_LIST_PRE}"
  echo " -j oe -o ${LOGDIR}/pre_f.log"
  echo " -v FLEXINPUT=$PRE_PROCESS_INPUT"
  echo " $PRE_PROCESS_QUEUE (optional: submit to a bigmem-queue)"
  echo " $EMAIL (optional: email notification)"
  echo " $ACCOUNT (optional: project account information)"
  echo " $pre_process_F_wait (optional: pre_process_F wait)"
endif


if ($BATCH_SYSTEM == "PBS") then
 set pre_fcommand = " ${QSUB_PATH}/qsub -N ${this_cycle}_preF ${JOB_START} $DSP -l ${RESOURCE_LIST_PRE} $PRE_PROCESS_QUEUE -j oe -o ${LOGDIR}/pre_f.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE ${pre_process_F_wait} ${PERL_FLEX}/pre_process_F.pl > ${LOGDIR}/moabID_pre_F"
 echo $pre_fcommand
 ${QSUB_PATH}/qsub -N ${this_cycle}_preF ${JOB_START} $DSP -l ${RESOURCE_LIST_PRE} $PRE_PROCESS_QUEUE -j oe -o ${LOGDIR}/pre_f.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE ${pre_process_F_wait} ${PERL_FLEX}/pre_process_F.pl > ${LOGDIR}/moabID_pre_F
 set exit_code = $?
 if ( $exit_code ) then
   echo "  Submit again because of failure on submitting pre_process_F.pl, exit_code: $exit_code" >> $job_err_log_name
   ${QSUB_PATH}/qsub -N ${this_cycle}_preF ${JOB_START} $DSP -l ${RESOURCE_LIST_PRE} $PRE_PROCESS_QUEUE -j oe -o ${LOGDIR}/pre_f.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE ${pre_process_F_wait} ${PERL_FLEX}/pre_process_F.pl > ${LOGDIR}/moabID_pre_F
   set exit_code = $?
 endif

else if ($BATCH_SYSTEM == "LSF") then
 setenv FLEXINPUT $PRE_PROCESS_INPUT
 bsub -J ${GSJOBID}_${this_cycle}_pre_F ${JOB_START} ${RESOURCE_LIST_PRE} -o ${LOGDIR}/pre_f.log -q share $EMAIL $ACCOUNT_KEY $QUEUE ${pre_process_F_wait} <${PERL_FLEX}/pre_process_F.pl >! ${LOGDIR}/moabID_pre_F

else if ($BATCH_SYSTEM == "INTER") then
 setenv FLEXINPUT $PRE_PROCESS_INPUT
 echo 0 >! ${LOGDIR}/moabID_pre_F
 ${PERL_FLEX}/pre_process_F.pl >&! ${LOGDIR}/pre_f.log
endif

# get the jobid of ${GSJOBID}_${this_cycle}_pre_F (pre_process_F.pl):
set wait_for_jobid = `cat ${LOGDIR}/moabID_pre_F`
echo JOB ${GSJOBID}_${this_cycle}_pre_F submitted - jobid: $wait_for_jobid

#LPC#
#exit

######################### submit rtfdda_postprocess.pl #########################
if ($POSTPROCESS) then
  echo ""
  if ($DEBUG) then
    echo "submitting ${PERL_FLEX}/rtfdda_postproc.pl with:"
    echo " -N ${this_cycle}_post"
    echo " -l ${RESOURCE_LIST_POST}"
    echo " -j oe -o ${LOGDIR}/post_process.log"
    echo " -v FLEXINPUT=$PRE_PROCESS_INPUT"
    echo " $POST_PROCESS_QUEUE (optional: submit to a bigmem-queue)"
    echo " $EMAIL (email notification - optional)"
    echo " $ACCOUNT_KEY (account - optional)"
    echo " -W depend=afterok:$wait_for_jobid"
  endif

  if ($BATCH_SYSTEM == "PBS") then

    set post_command = "${QSUB_PATH}/qsub -N ${this_cycle}_postproc ${JOB_START} $DSP -l ${RESOURCE_LIST_POST} -l ccm=1 -j oe -o ${LOGDIR}/post_process.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME} $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/rtfdda_postproc.pbs > ${LOGDIR}/moabID_post_process" 
    echo $post_command
    ${QSUB_PATH}/qsub -N ${this_cycle}_post $DSP -l ${RESOURCE_LIST_POST} -l ccm=1 -j oe -o ${LOGDIR}/post_process.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME} $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/rtfdda_postproc.pbs > ${LOGDIR}/moabID_post_process
    set exit_code = $?
    if ( $exit_code ) then
      echo "  Submit again because of failure on submitting rtfdda_postproc.pl, exit_code: $exit_code" >> $job_err_log_name
      ${QSUB_PATH}/qsub -N ${this_cycle}_post $DSP -l ${RESOURCE_LIST_POST} -l ccm=1 -j oe -o ${LOGDIR}/post_process.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME} $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/rtfdda_postproc.pbs > ${LOGDIR}/moabID_post_process
      set exit_code = $?
    endif

  else if ($BATCH_SYSTEM == "LSF") then

    setenv FLEXINPUT $PRE_PROCESS_INPUT

    bsub -J ${GSJOBID}_${this_cycle}_postprocess ${RESOURCE_LIST_POST} -o ${LOGDIR}/post_process.log -q share $EMAIL $ACCOUNT_KEY $QUEUE -w "done($wait_for_jobid)" <${PERL_FLEX}/rtfdda_postproc.pl >! ${LOGDIR}/moabID_post_process

  else if ($BATCH_SYSTEM == "INTER") then

    ${PERL_FLEX}/machinefile.pl -i ${GSJOBDIR}/nodes_available_post -m 1 -n 1 -o ${GSJOBDIR}/machinefile_post >>! ${GSJOBDIR}/logs/out_flexinput.log

# Check machine file

    if (! -e ${GSJOBDIR}/machinefile_post) then
       echo perl/machinefile.pl failed ... using "localhost" for postprocessing!
       set node_post = "localhost"
    else
# Grab head node
       if (! -z ${GSJOBDIR}/machinefile) then
          set node_post = `cat ${GSJOBDIR}/machinefile_post`
       else
          set node_post = "localhost"
       endif
    endif

    setenv FLEXINPUT $PRE_PROCESS_INPUT
    echo 0 >! ${LOGDIR}/moabID_post_process
    ssh $node_post "setenv FLEXINPUT $PRE_PROCESS_INPUT; ${PERL_FLEX}/rtfdda_postproc.pl >&! ${LOGDIR}/post_process.log " &

  endif


  # get the jobid of rtfdda_postprocess.pl:
  echo JOB ${GSJOBID}_${this_cycle}_postprocess submitted - jobid: `cat ${LOGDIR}/moabID_post_process`
endif

##################### submit the final analysis job ############################
echo ""
if ($DEBUG) then
  echo "submitting ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh with:"
  echo " -N ${this_cycle}_${MODEL}F"
  echo " -l ${RESOURCE_LIST}"
  echo " -j oe -o ${LOGDIR}/${MODEL}_F.log"
  echo " -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_F"
  echo " $EMAIL (email notification - optional)"
  echo " $ACCOUNT_KEY (account - optional)"
  echo " -W depend=afterok:$wait_for_jobid"
endif

if ($BATCH_SYSTEM == "PBS") then

  set final_analysis_command = "${QSUB_PATH}/qsub -N ${GSJOBID}_${cycle_label}_${MODEL}F $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_F.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_F $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_F"
  echo $final_analysis_command
  ${QSUB_PATH}/qsub -N {$cycle_label}_${MODEL}F $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_F.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_F $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_F
  set exit_code = $?
  if ( $exit_code ) then
    echo "  Submit again because of failure on submitting RT_L_MM_${MODEL}_rtfdda.csh, exit_code: $exit_code" >> $job_err_log_name
    ${QSUB_PATH}/qsub -N {$cycle_label}_${MODEL}F $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_F.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_F $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_F
    set exit_code = $?
  endif

else if ($BATCH_SYSTEM == "LSF") then

# Use an alias to turn around a bug in LSF (SCD extraview query 23261)
  alias bs "bsub -J ${GSJOBID}_${this_cycle}_${MODEL}_F ${RESOURCE_LIST} -o ${LOGDIR}/${MODEL}_F.log -q ${QUEUE_TYPE} $EMAIL $ACCOUNT_KEY -w "'"done($wait_for_jobid)"'
  bs < ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh >! ${LOGDIR}/moabID_F

else if ($BATCH_SYSTEM == "INTER") then

  echo 0 >! ${LOGDIR}/moabID_F
  setenv PBS_JOBID 0
  setenv CSHRC_RT  $GSJOBDIR/tmp/$this_cycle/cshrc
  setenv CSHRC_${MODEL} $RUNDIR/$this_cycle/cshrc.${MODEL}_F
  ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh >&! ${LOGDIR}/${MODEL}_F.log

endif

# get the jobid of the final analysis job:
set wait_for_jobid = `cat ${LOGDIR}/moabID_F`
echo JOB ${GSJOBID}_${this_cycle}_${MODEL}_F submitted - jobid: $wait_for_jobid

######################### submit veri_rtfdda_flex_${MODEL}.pl #########################
if ($VERI_MC) then
   setenv VTYPE MC
else
   setenv VTYPE flex
endif

if ($VERI3HCYC) then
  echo ""
  if ($DEBUG) then
    echo "submitting ${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl with:"
    echo " -N ${this_cycle}_veri"
    echo " -l ${RESOURCE_LIST_VERIF}"
    echo " -j oe -o ${LOGDIR}/verif_rtfdda.log"
    echo " -v FLEXINPUT=$PRE_PROCESS_INPUT"
    echo " $EMAIL (email notification - optional)"
    echo " $ACCOUNT_KEY (account - optional)"
    echo " -W depend=afterok:$wait_for_jobid"
  endif

  if ($BATCH_SYSTEM == "PBS") then

    set veri_command = "${QSUB_PATH}/qsub -N ${this_cycle}_veri $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/verif_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl > ${LOGDIR}/moabID_verif_rtfdda"
    echo $veri_command
    ${QSUB_PATH}/qsub -N ${this_cycle}_veri $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/verif_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl > ${LOGDIR}/moabID_verif_rtfdda
    set exit_code = $?
    if ( $exit_code ) then
      echo "  Submit again because of failure on submitting veri_rtfdda_${VTYPE}_${MODEL}.pl, exit_code: $exit_code" >> $job_err_log_name
      ${QSUB_PATH}/qsub -N ${this_cycle}_veri $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/verif_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl > ${LOGDIR}/moabID_verif_rtfdda
      set exit_code = $?
    endif

  else if ($BATCH_SYSTEM == "LSF") then

    setenv FLEXINPUT $PRE_PROCESS_INPUT

    bsub -J ${GSJOBID}_${this_cycle}_verif ${RESOURCE_LIST_VERIF} -o ${LOGDIR}/verif_rtfdda.log -q share $EMAIL $ACCOUNT_KEY -w "done($wait_for_jobid)" <${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl >! ${LOGDIR}/moabID_verif_rtfdda

  else if ($BATCH_SYSTEM == "INTER") then

    setenv FLEXINPUT $PRE_PROCESS_INPUT
    echo 0 >! ${LOGDIR}/moabID_verif_rtfdda
    ${PERL_FLEX}/veri_rtfdda_${VTYPE}_${MODEL}.pl >&! ${LOGDIR}/verif_rtfdda.log &

  endif

  # get the jobid of veri_rtfdda_${VTYPE}_${MODEL}.pl:
  echo JOB ${GSJOBID}_${this_cycle}_verif submitted - jobid: `cat ${LOGDIR}/moabID_verif_rtfdda`
endif

######################### submit Analog Ensemble plotting script #########################
if ($AnEn) then
  echo ""
  if ($DEBUG) then
    echo "submitting ${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pl with:"
    echo " -N ${GSJOBID}_${this_cycle}_AnEn"
    echo " -l ${RESOURCE_LIST_VERIF}"
    echo " -j oe -o ${LOGDIR}/AnEn_rtfdda.log"
    echo " -v FLEXINPUT=$PRE_PROCESS_INPUT"
    echo " $EMAIL (email notification - optional)"
    echo " $ACCOUNT (account - optional)"
    echo " -W depend=afterok:$wait_for_jobid"
  endif

  if ($BATCH_SYSTEM == "PBS") then

    set anen_command = "${QSUB_PATH}/qsub -N ${this_cycle}_AnEn $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/AnEn_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME}  $EMAIL $ACCOUNT_KEY $QUEUE ${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pbs > ${LOGDIR}/moabID_AnEn_rtfdda"
    echo $anen_command
    ${QSUB_PATH}/qsub -N ${this_cycle}_AnEn $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/AnEn_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME} $EMAIL $ACCOUNT_KEY $QUEUE ${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pbs > ${LOGDIR}/moabID_AnEn_rtfdda
    set exit_code = $?
    if ( $exit_code ) then
      echo "  Submit again because of failure on submitting AnEn_driver.py, exit_code: $exit_code" >> $job_err_log_name
      ${QSUB_PATH}/qsub -N ${this_cycle}_AnEn $DSP -l ${RESOURCE_LIST_VERIF} -j oe -o ${LOGDIR}/AnEn_rtfdda.log -v FLEXINPUT=$PRE_PROCESS_INPUT,MM5HOME=${MM5HOME} $EMAIL $ACCOUNT_KEY $QUEUE ${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pbs > ${LOGDIR}/moabID_AnEn_rtfdda
      set exit_code = $?
    endif

  else if ($BATCH_SYSTEM == "LSF") then

    setenv FLEXINPUT $PRE_PROCESS_INPUT

    bsub -J ${GSJOBID}_${this_cycle}_AnEn ${RESOURCE_LIST_VERIF} -o ${LOGDIR}/AnEn_rtfdda.log -q share $EMAIL $ACCOUNT -w "done($wait_for_jobid)" <${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pl >! ${LOGDIR}/moabID_AnEn_rtfdda

  else if ($BATCH_SYSTEM == "INTER") then

    setenv FLEXINPUT $PRE_PROCESS_INPUT
    echo 0 >! ${LOGDIR}/moabID_AnEn_rtfdda
    ${MM5HOME}/cycle_code/POSTPROCS/AnEn/AnEn_submit.pl >&! ${LOGDIR}/AnEn_rtfdda.log &

  endif
endif

########################## submit pre_process_P+FCST.pl ########################
if ($FCST_LENGTH) then
  echo ""
  if ($DEBUG) then
    echo "submitting ${PERL_FLEX}/pre_process_P+FCST.pl with:"
    echo " -N ${this_cycle}_preP"
    echo " -l ${RESOURCE_LIST_PRE_P}"
    echo " -j oe -o ${LOGDIR}/pre_p+fcst.log"
    echo " -v FLEXINPUT=$PRE_PROCESS_INPUT"
    echo " $EMAIL (email notification - optional)"
    echo " $ACCOUNT_KEY (account - optional)"
    echo " -W depend=afterok:$wait_for_jobid"
  endif

  if ($BATCH_SYSTEM == "PBS") then

    set pre_P_command = "${QSUB_PATH}/qsub -N ${this_cycle}_preP $DSP -l ${RESOURCE_LIST_PRE_P} -j oe -o ${LOGDIR}/pre_p+fcst.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/pre_process_P+FCST.pl > ${LOGDIR}/moabID_pre_P+FCST"
    echo $pre_P_command
    ${QSUB_PATH}/qsub -N ${this_cycle}_preP $DSP -l ${RESOURCE_LIST_PRE_P} -j oe -o ${LOGDIR}/pre_p+fcst.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/pre_process_P+FCST.pl > ${LOGDIR}/moabID_pre_P+FCST
    set exit_code = $?
    if ( $exit_code ) then
      echo "  Submit again because of failure on submitting pre_process_P+FCST.pl, exit_code: $exit_code" >> $job_err_log_name
      ${QSUB_PATH}/qsub -N ${this_cycle}_preP $DSP -l ${RESOURCE_LIST_PRE_P} -j oe -o ${LOGDIR}/pre_p+fcst.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${PERL_FLEX}/pre_process_P+FCST.pl > ${LOGDIR}/moabID_pre_P+FCST
      set exit_code = $?
    endif

  else if ($BATCH_SYSTEM == "LSF") then

    # Use an alias to turn around a bug in LSF (SCD extraview query 23261)
    alias bs "bsub -J ${GSJOBID}_${this_cycle}_pre_P+FCST ${RESOURCE_LIST_PRE} -o ${LOGDIR}/pre_p+fcst.log -q share  $EMAIL $ACCOUNT_KEY -w "'"done($wait_for_jobid)"'
    bs < ${PERL_FLEX}/pre_process_P+FCST.pl >! ${LOGDIR}/moabID_pre_P+FCST

  else if ($BATCH_SYSTEM == "INTER") then

    echo 0 >! ${LOGDIR}/moabID_pre_P+FCST
    ${PERL_FLEX}/pre_process_P+FCST.pl >! ${LOGDIR}/pre_p+fcst.log

  endif

  # get the jobid of the pre_process_P+FCST.pl?
  set wait_for_jobid = `cat ${LOGDIR}/moabID_pre_P+FCST`
  echo JOB ${GSJOBID}_${this_cycle}_pre_P+FCST submitted - jobid: $wait_for_jobid

######################## submit the prelim + forecast job ######################
  echo ""
  if ($DEBUG) then
    echo "submitting ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh with:"
    echo " -N ${this_cycle}_${MODEL}P"
    echo " -l ${RESOURCE_LIST}"
    echo " -j oe -o ${LOGDIR}/${MODEL}_P+FCST.log"
    echo " -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_P+FCST"
    echo " $EMAIL (email notification - optional)"
    echo " $ACCOUNT_KEY (account - optional)"
    echo " -W depend=afterok:$wait_for_jobid"
  endif

  if ($BATCH_SYSTEM == "PBS") then

    set P_fcst_command = "${QSUB_PATH}/qsub -N ${cycle_label}_${MODEL}P $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_P+FCST.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_P+FCST $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_P+FCST"
    echo $P_fcst_command
    ${QSUB_PATH}/qsub -N ${cycle_label}_${MODEL}P $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_P+FCST.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_P+FCST $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_P+FCST
    set exit_code = $?
    if ( $exit_code ) then
      echo "  Submit again because of failure on submitting prelim + forecast job, exit_code: $exit_code" >> $job_err_log_name
      ${QSUB_PATH}/qsub -N ${cycle_label}_${MODEL}P $DSP -l ${RESOURCE_LIST} -j oe -o ${LOGDIR}/${MODEL}_P+FCST.log -v CSHRC_RT=$GSJOBDIR/tmp/$this_cycle/cshrc,CSHRC_${MODEL}=$RUNDIR/$this_cycle/cshrc.${MODEL}_P+FCST $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterok:$wait_for_jobid ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh > ${LOGDIR}/moabID_P+FCST
      set exit_code = $?
    endif

  else if ($BATCH_SYSTEM == "LSF") then

    # Use an alias to turn around a bug in LSF (SCD extraview query 23261)
    alias bs "bsub -J ${GSJOBID}_${this_cycle}_${MODEL}_P+FCST ${RESOURCE_LIST} -o ${LOGDIR}/${MODEL}_P+FCST.log -q ${QUEUE_TYPE} $EMAIL $ACCOUNT_KEY -w "'"done($wait_for_jobid)"'
    bs < ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh >! ${LOGDIR}/moabID_P+FCST

  else if ($BATCH_SYSTEM == "INTER") then
    echo 0 >! ${LOGDIR}/moabID_P+FCST
    setenv PBS_JOBID 0
    setenv CSHRC_RT $GSJOBDIR/tmp/$this_cycle/cshrc
    setenv CSHRC_${MODEL} $RUNDIR/$this_cycle/cshrc.${MODEL}_P+FCST
    ${CSH_ARCHIVE}/Forecast/RT_L_MM_${MODEL}_rtfdda.csh >! ${LOGDIR}/${MODEL}_P+FCST.log

  endif

  # get the jobid of the P+FCST job?
  set wait_for_jobid = `cat ${LOGDIR}/moabID_P+FCST`
  echo JOB ${GSJOBID}_${this_cycle}_${MODEL}_P+FCST submitted - jobid: $wait_for_jobid
endif

######################### submit post_process_clean.pl #########################
echo ""

if ($BATCH_SYSTEM == "PBS") then

  set clean_command = "${QSUB_PATH}/qsub -N ${this_cycle}_cln $DSP -l ${RESOURCE_LIST_CLEAN} -j oe -o ${LOGDIR}/clean.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterany:$wait_for_jobid ${PERL_FLEX}/post_process_clean.pl > ${LOGDIR}/moabID_post_clean"
  echo $clean_command
  ${QSUB_PATH}/qsub -N ${this_cycle}_cln $DSP -l ${RESOURCE_LIST_CLEAN} -j oe -o ${LOGDIR}/clean.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterany:$wait_for_jobid ${PERL_FLEX}/post_process_clean.pl > ${LOGDIR}/moabID_post_clean
  set exit_code = $?
  if ( $exit_code ) then
    echo "  Submit again because of failure on submitting post_process_clean.pl, exit_code: $exit_code" >> $job_err_log_name
    ${QSUB_PATH}/qsub -N ${this_cycle}_cln $DSP -l ${RESOURCE_LIST_CLEAN} -j oe -o ${LOGDIR}/clean.log -v FLEXINPUT=$PRE_PROCESS_INPUT $EMAIL $ACCOUNT_KEY $QUEUE -W depend=afterany:$wait_for_jobid ${PERL_FLEX}/post_process_clean.pl > ${LOGDIR}/moabID_post_clean
    set exit_code = $?
  endif

else if ($BATCH_SYSTEM == "LSF") then

# Use an alias to turn around a bug in LSF (SCD extraview query 23261)
  alias bs "bsub -J ${GSJOBID}_${this_cycle}_clean ${RESOURCE_LIST_CLEAN} -o ${LOGDIR}/clean.log -q share $EMAIL $ACCOUNT_KEY -w "'"ended($wait_for_jobid)"'

  bs < ${PERL_FLEX}/post_process_clean.pl >! ${LOGDIR}/moabID_post_clean

else if ($BATCH_SYSTEM == "INTER") then
  echo 0 >! ${LOGDIR}/moabID_post_clean
  ${PERL_FLEX}/post_process_clean.pl >! ${LOGDIR}/clean.log
endif

set wait_for_jobid = `cat ${LOGDIR}/moabID_post_clean`
echo JOB ${GSJOBID}_${this_cycle}_clean submitted - jobid: $wait_for_jobid

exit 0
