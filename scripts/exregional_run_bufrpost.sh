#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHdir/source_util_funcs.sh
source_config_for_task "task_run_bufrpost" ${GLOBAL_VAR_DEFNS_FP}
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; . $USHdir/preamble.sh; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( $READLINK -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs the BUFR post-processor on
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set OpenMP variables.
#
#-----------------------------------------------------------------------
#
export KMP_AFFINITY=${KMP_AFFINITY_RUN_BUFRPOST}
export OMP_NUM_THREADS=${OMP_NUM_THREADS_RUN_BUFRPOST}
export OMP_STACKSIZE=${OMP_STACKSIZE_RUN_BUFRPOST}
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
eval ${PRE_TASK_CMDS}

nprocs=$(( NNODES_RUN_BUFRPOST*PPN_RUN_BUFRPOST ))

if [ -z "${RUN_CMD_BUFRPOST:-}" ] ; then
  print_err_msg_exit "\
  Run command was not set in machine file. \
  Please set RUN_CMD_BUFRPOST for your platform"
else
  print_info_msg "$VERBOSE" "
  All executables will be submitted with command \'${RUN_CMD_BUFRPOST}\'."
fi
#
#-----------------------------------------------------------------------
#
# Remove any files from previous runs and stage necessary files in the 
# temporary work directory specified by DATA_FHR.
#
#-----------------------------------------------------------------------
#
rm_vrfy -f fort.*

# ====================================================================
## DATA_FHR = \"${DATA_FHR}\"
# ===================================================================="
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from CDATE.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${PDY}
hh=${cyc}
#
#-----------------------------------------------------------------------
#
# Create the namelist file (itag) containing arguments to pass to the post-
# processor's executable.
#
#-----------------------------------------------------------------------
#
#
#
# Set the names of the forecast model's write-component output files.
#
if [ "${RUN_ENVIR}" = "nco" ]; then
    DATAFCST=$DATAROOT/run_fcst${dot_ensmem/./_}.${share_pid}
else
    DATAFCST=$DATA
fi

dyn_file="${DATAFCST}/dynf${fhr}.nc"
phy_file="${DATAFCST}/phyf${fhr}.nc"
#
#
#-----------------------------------------------------------------------
#
# Run the bufrpost executable in the temporary directory (DATA) for this
# output time.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Starting BUFR post-processing..."

# need profdat file, and profilm file, and itag file

tmmark=tm00

cp  /lfs/h2/emc/lam/noscrub/Matthew.Pyle/ufs_srw_bufr/fix/fix_lam/hiresw_conusfv3sar_lambert_profdat_conus25km rrfs_profdat

PREP_STEP

export FORT19="$DATA_FHR/rrfs_profdat"
export FORT79="$DATA_FHR/profilm.c1.${tmmark}"
export FORT11="itag"

model=FV3S
OUTTYP=netcdf
NFILE=1
INCR=01
NSTAT=1850  # how automate?

YYYY=`echo $PDY | cut -c1-4`
MM=`echo $PDY | cut -c5-6`
DD=`echo $PDY | cut -c7-8`

STARTDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00

cat > itag <<EOF
$dyn_file
$phy_file
$model
$OUTTYP
$STARTDATE
$NFILE
$INCR
$fhr
$NSTAT
$dyn_file
$phy_file
EOF


#worked eval ${EXECdir}/rrfs_bufr.x < itag || print_err_msg_exit "\
eval ${RUN_CMD_BUFRPOST} ${EXECdir}/rrfs_bufr.x < itag ${REDIRECT_OUT_ERR} || print_err_msg_exit "\
Call to executable to run bufrpost for forecast hour $fhr returned with non-
zero exit code."
POST_STEP
#
#-----------------------------------------------------------------------
#
# Move and rename the output files from the work directory to their final 
# location in COMOUT.  Also, create symlinks in COMOUT to the
# grib2 files that are needed by the data services group.  Then delete 
# the work directory.
#
#-----------------------------------------------------------------------
#
#
# cd_vrfy "${COMOUT}"
# basetime=$( $DATE_UTIL --date "$yyyymmdd $hh" +%y%j%H%M )
# symlink_suffix="${dot_ensmem}.${basetime}f${fhr}${post_mn}"

# rm_vrfy -rf ${DATA_FHR}

# Delete the forecast directory
# fhr_l=$(printf "%03d" $FCST_LEN_HRS)
# if [ $RUN_ENVIR = "nco" ] && [ $KEEPDATA = "FALSE" ] && [ $fhr = $fhr_l ]; then
#    rm -rf $DATAFCST
# fi
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Post-processing for forecast hour $fhr completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

