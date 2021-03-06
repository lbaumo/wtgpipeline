#! /bin/bash -xv

### script to register image sets
###
### the astro-/photometry is via SCAMP 
###
### $Id: do_Subaru_register_template.sh,v 1.20 2009-05-15 01:10:00 dapple Exp $


. progs.ini
. bash_functions.include

REDDIR=`pwd`

export SUBARUDIR=/nfs/slac/g/ki/ki05/anja/SUBARU

cluster="MACS1931-26"  # cluster nickname as in /nfs/slac/g/ki/ki02/xoc/anja/SUBARU/SUBARU.list

FILTERS="W-J-B W-J-V W-C-RC W-C-IC W-S-Z+ W-C-IC_2007-07-18_CALIB W-C-RC_2007-07-18_CALIB W-J-B_2007-07-18_CALIB W-J-V_2007-07-18_CALIB W-S-Z+_2007-07-18_CALIB"


IMAGESIZE="12000,12000"

# Do astrometric calibration with SCAMP or ASTROMETRIX (no longer supported in this script) ?
ASTROMMETHOD=SCAMP

# only for Scamp (use SDSS-R6,  NOMAD-1, or 2MASS ) :
ASTROMETRYCAT=2MASS

ASTROMADD=""
if [ ${ASTROMMETHOD} = "SCAMP" ]; then
   ASTROMADD="_scamp_${ASTROMETRYCAT}"
   
fi

# need to keep track of the max number of NCHIPS for scamp
NCHIPSMAX=0

###############################################
######################
#Some Setup Stuff

export BONN_TARGET=${cluster}
export BONN_FILTER=${FILTERS}

lookupfile=/nfs/slac/g/ki/ki05/anja/SUBARU/SUBARU.list

ra=`grep ${cluster} ${lookupfile} | awk '{print $3}'`
dec=`grep ${cluster} ${lookupfile} | awk '{print $4}'`

echo ${cluster} ${ra} ${dec}

LINE=""

#######################################
## Reset Logger
./BonnLogger.py clear

#########################################
### Capture Variables
./BonnLogger.py config \
    cluster=${cluster} \
    filterlist="${FILTERS}" \
    imagesize="${IMAGESIZE}" \
    astrommethod="${ASTROMMETHOD}" \
    astrometrycat="${ASTROMETRYCAT}" \
    astromadd="${ASTROMADD}"
    

##############################
### prep stuff, per filter ###
##############################


for filter in ${FILTERS}
do

  export BONN_FILTER=${filter}
  echo ${filter}
  ./BonnLogger.py clear

  ./setup_general.sh ${SUBARUDIR}/${cluster}/${filter}/SCIENCE instrument_$$
  INSTRUMENT=`cat instrument_$$`
  rm instrument_$$

  if [ ${INSTRUMENT} == "UNKNOWN" ]; then
      echo "INSTRUMENT UNKNOWN: Defaulting to SUBARU"
      echo "Need to add INSTRUM key to ${SUBARUDIR}/${cluster}/${filter}/SCIENCE files if otherwise!"
      read -p 'Set INSTRUM to SUBARU [y/n]?' confirm
      if [ ${confirm} == 'y' ]; then
	  ./setup_SUBARU.sh ${SUBARUDIR}/${cluster}/${filter}/SCIENCE
	  INSTRUMENT=SUBARU
	  ./update_config_header.sh ${SUBARUDIR}/${cluster}/${filter}/SCIENCE ${INSTRUMENT} ${cluster}
      else
	  read -p 'Set INSTRUM to MEGAPRIME [y/n]?' confirm2
	  if [ ${confirm2} == 'y' ]; then
	      INSTRUMENT=MEGAPRIME
	      ./update_config_header_megaprime.sh ${SUBARUDIR}/${cluster}/${filter}/SCIENCE ${INSTRUMENT} ${cluster}
	  else
	      echo "Need to add INSTRUM key to ${SUBARUDIR}/${cluster}/${filter}/SCIENCE files."
	      exit 2;
	  fi
      fi
  fi

  #Find Ending
  case ${filter} in
      "I" )
	  ending=mos
	  ;;
      "u" )
	  ending=C
	  ;;
      * )
	  testfile=`ls -1 $SUBARUDIR/$cluster/${filter}/SCIENCE/*_2*.fits | awk 'NR>1{exit};1'`
	  ending=`basename ${testfile} | awk -F'_2' '{print $2}' | awk -F'.' '{print $1}'`	  
	  ;;
  esac


  echo ${NCHIPS}

  echo ${INSTRUMENT}

  . ${INSTRUMENT:?}.ini
  export INSTRUMENT

  echo ${NCHIPS}

  ./BonnLogger.py clear
  ./BonnLogger.py config \
      cluster=${cluster} \
      filter=${filter} \
      config=${config}

  ##########################
  ### prepare coaddition ###
  ##########################


  ./test_coadd_ready.sh ${SUBARUDIR}/${cluster} ${filter} ${ending}


#  if [ -d ${SUBARUDIR}/${cluster}/${filter}/SCIENCE/cat_scamp ]; then
#      rm -rf ${SUBARUDIR}/${cluster}/${filter}/SCIENCE/cat_scamp
#  fi

  if [ ! -d ${SUBARUDIR}/${cluster}/${filter}/SCIENCE/cat_scamp ]; then
  ###adds astrometric info; makes directory cat with ${image}_${chip}*.cat
  ./parallel_manager.sh ./create_astromcats_scamp_para.sh ${SUBARUDIR}/${cluster}/${filter} SCIENCE WEIGHTS
  fi

  ### prep for scamp:
  LINE="${LINE} ${SUBARUDIR}/${cluster}/${filter} SCIENCE "

  if [ ${NCHIPS} -gt ${NCHIPSMAX} ];then
      NCHIPSMAX=${NCHIPS}
  fi

done


echo ${LINE}
echo ${NCHIPSMAX}
export NCHIPSMAX

####################################################################
### astrometric and photometric calibration:                     ###
###   this can be done with scamp for all filters simultaneously ###
###   or with astrometrix and photometrix                        ###
####################################################################

if [ ${ASTROMMETHOD} != "SCAMP" ]; then

    echo "This script supports only registration via scamp."
    echo "Use an older version for use with astrometrix."
    exit 2;
  
else
    
  export BONN_FILTER=${FILTERS}

  ./BonnLogger.py clear
  ./BonnLogger.py config \
      cluster=${cluster} \
      filterlist="${FILTERS}" \
      astrommethod=${ASTROMMETHOD} \
      astrometrycat=${ASTROMETRYCAT} \

  ./create_scamp_astrom_photom.sh ${LINE} ${ASTROMETRYCAT}

fi




