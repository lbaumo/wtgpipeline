#!/bin/bash -xv
#adam-BL#. BonnLogger.sh
#adam-BL#. log_start
# ----------------------------------------------------------------
# File Name:           create_skysub_para.sh
# Author:              Thomas Erben (terben@astro.uni-bonn.de)
# Last modified on:    10.02.2015
# Description:         Performs sky subtraction of FITS images
#                      obtained in optical wavelengths
# ----------------------------------------------------------------

# Script history information:
# 24.09.2007:
# Script started (significant rewrite from an old script)
#
# 26.09.2007:
# - update of documentation
# - more robust treatment for a wrong skysubtraction mode
# - The subtraction modes are called ONEPASS and TWOPASS now
#
# 28.09.2007:
# - I corrected bugs in the deletion of temporary files
# - I test whether maindir/sciencedir exists at all
#
# 19.10.2007:
# The special cleanTmpFiles function (arguments) 
# for this script required
# a rearrangement of the trap function handling program 
# interruption.
#
# 10.02.2015:
# getting skyback1 from weighted ${FILE} rather than standard ${FILE}
# so that guider shadows don't do weird things to the background

# File inclusions:
. progs.ini

# define various variables because of the '-u' script flag
# (the use of undefined variables will be treated as errors!)
# several variables might be used uninitialised 
# in the cleanTmpFiles function.
THELI_DEBUG=${THELI_DEBUG:-""}
CHIP=${CHIP:-""}
BASE=${BASE:-""}
i=1
while [ ${i} -le ${NCHIPS} ]
do
  RESULTDIR[${i}]=${RESULTDIR[${i}]:-""}
  i=$(( $i + 1 ))
done

##
## function definitions:
##
function printUsage 
{
  echo "SCRIPT NAME:"
  echo "    create_skysub_para.sh"
  echo ""
  echo "ARGUMENTS:"
  echo "    1. main_dir."
  echo "    2. set_dir."
  echo "    3. image_extension"
  echo "    4. extension_addition"
  echo "    5. ONEPASS or TWOPASS"
  echo "   (6. chips to be processed)"
  echo ""
  echo "DESCRIPTION: "
  echo "    The script subtracts the sky background from astronomical"
  echo "    images obtained in optical wavelengths.  It supports two different"
  echo "    modes, a one-pass and a two-pass sky subtraction (5th command line"
  echo "    argument):"
  echo ""
  echo "    - ONEPASS:"
  echo "      We subtract the sky background with the standard SExtractor"
  echo "      procedure. The relevant SExtractor parameters in this case "
  echo "      are:"
  echo ""
  echo "      BACK_SIZE 128, BACK_FILTERSIZE 3"
  echo ""
  echo "    - TWOPASS:"
  echo "      In the two-pass case we first detect objects with SExtractor,"
  echo "      relpace pixels occupied by objects with the 'mode' of the image"
  echo "      and run SExtractor skybackground subtractionon the new, masked image. "
  echo "      The estimated background is then subtracted from the original"
  echo "      image."
  echo "      The relevant SExtractor parameters for this procedure are:"
  echo " "
  echo "      - First object detection:"
  echo "        DETECT_MINAREA 50, DETECT_THRESH   1.3 "
  echo ""
  echo "        The large detection minarea together with a low threshold"
  echo "        ensures that also halos around bright stars are masked."
  echo ""
  echo "      - Sky subtraction of the masked image:"
  echo "        BACK_SIZE 90, BACK_FILTERSIZE 5"
  echo "    "
  echo "    The TWOPASS mode avoids that the background around bright objects "
  echo "    is biased too high and hence is preferable to the ONEPASS mode."
  echo "    However, check your images creafully whether it can be applied:"
  echo ""
  echo "    THE INITIAL IMAGE MUST BE REASONABLY FLAT FOR THE TWOPASS"
  echo "    MODE."
  echo ""
  echo "    If it shows large scale gradients or fringe residuals it will give"
  echo "    very wrong results and spoil photometric measurements later on."
  echo "    Image imperfections might errorneously be identified as objects"
  echo "    and wrongly be masked in the first pass or the calculated mode for"
  echo "    the whole image is not a good estimate for the whole image which"
  echo "    leads to a wrong background subtraction in the second pass.  "
  echo ""
  echo "    If your images suffer from a non-flat background or other "
  echo "    high-frequency residuals (such as fringes) use the ONEPASS "
  echo "    sky-subtraction."
  echo ""
  echo "EXAMPLE:"
  echo "    parallel_manager.sh create_skysub_new_para.sh \\"
  echo "                        /aibn85_2/terben/TEST/ \\"
  echo "                        set_1 OFCSF .sub ONEPASS"
  echo ""
  echo "    Subtract the skybackground in one pass from all images"
  echo "    in the directory /aibn85_2/terben/TEST/set_1 with"
  echo "    the ending 'OFCSF'. The ending of the result images"
  echo "    will be 'OFCSF.sub' ."
  echo ""
  echo "    (e. g. WFI.2000-12-27T07:57:29.376_1OFCSF.fits ->"
  echo "           WFI.2000-12-27T07:57:29.376_1OFCSF.sub.fits)"
  echo ""
  echo "AUTHOR:"
  echo "    Thomas Erben (terben@astro.uni-bonn.de)"
}

function cleanTmpFiles
{
    if [ -z ${THELI_DEBUG} ]; then
        echo "Cleaning temporary files for script $0"

	for CHIP in ${!#}
        do
          test -f ${TEMPDIR}/skysub_images_${CHIP}_$$ && \
               rm ${TEMPDIR}/skysub_images_${CHIP}_$$

          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_weighted.fits    -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_backsub.fits    -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_noobj.fits      -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_noobj_mode.fits -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_skyback.fits    -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_backsub1.fits    -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_skyback1.fits    -exec rm {} \;
          ${P_FIND} ${RESULTDIR[${CHIP}]} \
                    -name \*_${CHIP}$1_backsub_noobj.fits    -exec rm {} \;
        done
    else
        echo "Variable THELI_DEBUG set! No cleaning of temp. files in script $0"    
    fi
}

##
## initial sanity checks
##

# check validity of command line arguments:
if [ $# -ne 6 ]; then
    printUsage
    #adam-BL#log_status 1 "Invalid Command Line"
    exit 1
fi

# Handling of program interruption by CRTL-C
trap "echo 'Script $0 interrupted!! Cleaning up and exiting!'; \
      cleanTmpFiles $3 \"${!#}\"; exit 1" INT
      #adam-BL#log_status 1 'Interupt'


# Existence of image directory:
test -d /$1/$2 || { echo "Can't find directory /$1/$2"; exit 1; } #adam-BL#log_status 1 "Can't find directory /$1/$2"

##
## The main script starts here:
##
for CHIP in ${!#}
do  ${P_FIND} /$1/$2/ -maxdepth 1 -name \*_${CHIP}$3.fits > \
            ${TEMPDIR}/skysub_images_${CHIP}_$$

  # determine where the FITS files (result and intermediary)
  # finally go (THELI link structure)

  FILE=`${P_GAWK} '(NR==1) {print $0}' ${TEMPDIR}/skysub_images_${CHIP}_$$`

#### changed from creat_skysub_delink_para.sh
#  if [ -L ${FILE} ]; then
#    LINK=`${P_READLINK} ${FILE}`
#    RESULTDIR[${CHIP}]=`dirname ${LINK}`
#  else
    RESULTDIR[${CHIP}]="/$1/$2"
#  fi  
####
  
  # do the real job here:
  while read FILE
  do
    BASE=`basename ${FILE} .fits`

    if [ "$5" = "ONEPASS" ]
    then
      # In the one-pass case we 'just' subtract the background
      # with the standard SExtractor procedure:
      ${P_SEX} ${FILE} \
               -c ${DATACONF}/skysub.conf.sex\
               -BACK_SIZE 128 -BACK_FILTERSIZE 3\
               -CHECKIMAGE_TYPE -BACKGROUND\
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_backsub.fits"

    elif [ "$5" = "TWOPASS" ]
    then
      # In the two-pass case we first detect objects, relpace pixels
      # occupied by objects with the 'mode' of the image and run
      # SExtractor on the new, masked image. Note that the initial
      # image needs to be reasonably flat for this to work properly.

      # First SExtractor to remove objects:
      ${P_SEX} ${FILE} -c ${DATACONF}/image-objects.sex\
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" \
	  -DETECT_MINAREA 7 \
	  -DETECT_THRESH  3 \
	  -ANALYSIS_THRESH 3

      # Now the mode of the original image. To obtain a good
      # estimate we use the original image with the objects removed
      # already:

      if [ "${INSTRUMENT}" = "SUBARU" ]; then

	  MODE=`${P_IC} '%1 -70000 %2 fabs 1.0e-06 > ?' \
              ${FILE} \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" | \
	      ${P_IC} '%1 -70000 %2 0 == ?' - $1/WEIGHTS/${BASE}.flag.fits | \
              ${P_STATS} | ${P_GAWK} '($1=="mode") {print $3}'`

      # substitute object pixels in the original image with the mode
      # and run SExtractor background subtraction on that image.
      # Afterwards this background needs to be subtrackted from the
      # original image:


	  ${P_IC} '%1 '${MODE}' %2 fabs 1.0e-06 > ?' \
              ${FILE} \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" | \
	      ${P_IC} '%1 '${MODE}' %2 0 == ?' - $1/WEIGHTS/${BASE}.flag.fits > \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits"
	  
      else
	  
	  MODE=`${P_IC} '%1 -70000 %2 fabs 1.0e-06 > ?' \
                    ${FILE} \
                    ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" | \
                    ${P_STATS} | ${P_GAWK} '($1=="mode") {print $3}'`

	  ${P_IC} '%1 '${MODE}' %2 fabs 1.0e-06 > ?' \
              ${FILE} \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" > \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits"

	  
      fi


      ${P_SEX} -c ${DATACONF}/skysub.conf.sex \
               ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits" \
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_skyback.fits" \
               -BACK_SIZE 90

      ${P_IC} '%1 %2 -' ${FILE} \
                        ${RESULTDIR[${CHIP}]}/${BASE}"_skyback.fits" >\
                        ${RESULTDIR[${CHIP}]}/${BASE}"_backsub.fits"

    elif [ "$5" = "THREEPASS" ]
    then
      # This is the true two-pass method...
      # First, take out the large-scale gradient, as they mess up the
      # very small detection threshold we use later.

      # First SExtractor call:
      #adam# new stuff begins here
      #adam# getting skyback1 from weighted ${FILE} rather than standard ${FILE}, so that guider shadows don't do weird things to the background
      ${P_IC} '%1 NaN %2 0 == ?' ${FILE} $1/WEIGHTS/${BASE}.flag.fits > ${RESULTDIR[${CHIP}]}/${BASE}"_weighted.fits"
      sex ${RESULTDIR[${CHIP}]}/${BASE}"_weighted.fits" \
               -c ${DATACONF}/skysub.conf.sex\
               -BACK_SIZE 1024 -BACK_FILTERSIZE 1 \
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_skyback1.fits"
      #adam# new stuff ends here

      ${P_IC} '%1 %2 -' ${FILE} \
	      ${RESULTDIR[${CHIP}]}/${BASE}"_skyback1.fits" \
	      > ${RESULTDIR[${CHIP}]}/${BASE}"_backsub1.fits" \


      # Now remove objects:
      sex ${RESULTDIR[${CHIP}]}/${BASE}"_backsub1.fits" \
          -c ${DATACONF}/image-objects.sex\
          -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" \
	  -DETECT_MINAREA 5 \
	  -DETECT_THRESH  0.7 \
	  -ANALYSIS_THRESH 0.7 

      # substitute object pixels in the original image with NaN
      # and run SExtractor background subtraction on that image.
      # Afterwards this background needs to be subtrackted from the
      # original image:

      if [ "${INSTRUMENT}" = "SUBARU" ]; then
          #adam# check: if #2>1.0e-06 
          #adam# check: have to comment out the thing that deletes these images
	  #adam# 't f c ?', t=backsub1.fits, f=NaN, c=fabs(noobj.fits)>1.0e-06
	  ${P_IC} '%1 NaN %2 fabs 1.0e-06 > ?' \
              ${RESULTDIR[${CHIP}]}/${BASE}"_backsub1.fits" \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" | \
	      ${P_IC} '%1 NaN %2 0 == ?' - $1/WEIGHTS/${BASE}.flag.fits > \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits"
	  #adam# 't f c ?', t=backsub1.fits[w/ objects set to NaN], f=NaN, c=flag.fits==0
	  
      else

	  ${P_IC} '%1 NaN %2 fabs 1.0e-06 > ?' \
              ${RESULTDIR[${CHIP}]}/${BASE}"_backsub1.fits" \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj.fits" > \
              ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits"

      fi


      ${P_SEX_286} -c ${DATACONF}/skysub.conf.sex \
               ${RESULTDIR[${CHIP}]}/${BASE}"_noobj_mode.fits" \
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_skyback.fits" \
               -BACK_SIZE 256 -BACK_FILTERSIZE 2 \

      ${P_IC} '%1 %2 -' ${RESULTDIR[${CHIP}]}/${BASE}"_backsub1.fits" \
                        ${RESULTDIR[${CHIP}]}/${BASE}"_skyback.fits" >\
                        ${RESULTDIR[${CHIP}]}/${BASE}"_backsub.fits"
    else
      echo "Unknown background subtraction mode: $5; Exiting !!"
      #adam-BL#log_status 1 "Unknown background subtraction mode: $5"
      exit 1
    fi


    # We again estimate the mode of the 'skysubtracted' images and subtract
    # it. SExtractor seems to be biased low by a small margin.
      ${P_SEX} ${RESULTDIR[${CHIP}]}/${BASE}"_backsub.fits" -c ${DATACONF}/image-objects.sex\
               -CHECKIMAGE_NAME ${RESULTDIR[${CHIP}]}/${BASE}"_backsub_noobj.fits" \
	  -DETECT_MINAREA 5 \
	  -DETECT_THRESH  2.0 \
	  -ANALYSIS_THRESH 2.0 

    MODE=`${P_STATS} < ${RESULTDIR[${CHIP}]}/${BASE}"_backsub_noobj.fits" |\
          ${P_GAWK} '($1=="mode") {print $3}'`

    ${P_IC} '%1 '${MODE}' -' ${RESULTDIR[${CHIP}]}/${BASE}"_backsub.fits" > \
                             ${RESULTDIR[${CHIP}]}/${BASE}"$4.fits"
    exit_status=$?
    if [ "$exit_status" != "0" ]; then
	#adam-BL#log_status $exit_status "IC Failure"
	exit $exit_status
    fi
	

    # and finally a link if necessary:
    if [ "${RESULTDIR[${CHIP}]}" != "/$1/$2" ]; then
      ln -s ${RESULTDIR[${CHIP}]}/${BASE}"$4.fits" /$1/$2/${BASE}"$4.fits"
    fi
        
  done < ${TEMPDIR}/skysub_images_${CHIP}_$$
done

# clean up and bye:
cleanTmpFiles $3 "${!#}"


#adam-BL#log_status 0
