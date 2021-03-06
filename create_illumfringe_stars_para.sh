#!/bin/bash -xv
. BonnLogger.sh
. log_start
# script that creates an illumination correction and
# fringe image out of a blank sky field (superflat)
# $Id: create_illumfringe_stars_para.sh,v 1.5 2008-07-18 17:07:22 dapple Exp $

# $1: main dir (filter)
# $2: Science directory
# $3: smoothing scale (use 256 for default)
# $4: chips to be processed

# preliminary work:
. ${INSTRUMENT:?}.ini

for CHIP in $4
do
  FILE=`ls $1/$2/$2_${CHIP}.fits`

  if [ ! -s $1/$2/$2_${CHIP}.fits ]; then
      log_status 2 "Science Image Missing: ${CHIP}"
      exit 2
  fi


  ###

  if [ -e $1/$2/$2_${CHIP}_illum.fits ]; then
      rm $1/$2/$2_${CHIP}_illum${3}.fits
  fi
  ${P_SEX} /$1/$2/$2_${CHIP}.fits -c ${CONF}/illumfringe_back.sex -CHECKIMAGE_NAME $1/$2/$2_${CHIP}_illum${3}.fits -BACK_SIZE $3

  if [ ! -s $1/$2/$2_${CHIP}_illum${3}.fits ]; then
      log_status 3 "Illum Image not produced: ${CHIP}"
      exit 3
  fi

  ###

  if [ -e $1/$2/$2_${CHIP}_fringe${3}.fits ]; then
      rm $1/$2/$2_${CHIP}_fringe${3}.fits
  fi
  ${P_SEX} /$1/$2/$2_${CHIP}.fits -c ${CONF}/illumfringe_fringe.sex -CHECKIMAGE_NAME $1/$2/$2_${CHIP}_fringe${3}.fits -BACK_SIZE $3

  if [ ! -s $1/$2/$2_${CHIP}_fringe${3}.fits ]; then
      log_status 4 "Fringe image not produced: ${chip}"
      exit 4
  fi

  ###
done

log_status $?
