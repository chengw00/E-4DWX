#!/bin/bash
function usage {
  echo "Usage: $0 -m <machine name> [-v] [-r] [-g] [-u]"
  echo "Optional '-v' : wrf version, defaults to wrfv3.8.1"
  echo "Optional '-r' : build one range, e.g. GWWSMR, defaults to build all"
  echo "Optional '-t' : checkout from tag"
  echo "Optional '-g' : no git clone; existing local repository will be used"
  echo "Optional '-u' : updating of local repository will be performed"
}

set -x

cwd=`pwd`

BUILDWORKBASE=/glade/scratch/chengw/git/test/E-4DWX
[ -d /p/work1/$USER ] && BUILDWORKBASE=/p/work1/$USER

# set env vars if user hasn't set them
if [ -z $BUILD_WORK ]; then
  BUILD_WORK=$BUILDWORKBASE/build_work
fi

if [ -z $DEST ]; then
export  DEST=$BUILDWORKBASE/build_E-4DWX
fi

RANGES="GETAC"

if [ -z $MEMBERS ]; then
MEMBERS="G00_WCTRL G00_WSKEB G01_WCBMJ G02_WCGDE G02_WPQNS G03_WMMOR G04_WMWD5 G05_WMWS6 G06_WPBOU G06_WRCAM G07_WPMYJ G08_WPMYN G09_WPNTP G10_WMMOR G10_WPQNS G11_WMWD5 G11_WPSHN G12_WMWS6 G12_WPUWA G13_WCBMJ G13_WRCAM G14_WPNTP G14_WSKE2 G15_WCTRL G15_WSKEB G16_WPMYN G17_WPBOU G18_WPSHN G19_WPUWA G20_WCGDE GFS_WCTRL NAM_WCTRL"
fi

export VERSION=wrfv3.8.1	# default is to use current wrf version 
GIT=1				# default is to do git clone
TAG=				# need to specify tag, if want to check out from a tag
UPDATE=				# default is not to update local repository
RANGE=				# allow user to input one range, default is to build all

while getopts m:v:t:r:guh FLAG
do
   case $FLAG in
   m) # machine
      export MACHINE=`echo $OPTARG | tr '[:upper:]' '[:lower:]'`
      ;;
   v) # flag for wrf version number
     export VERSION=$OPTARG
      ;;
   r) # range
      export RANGE=$OPTARG
      ;;
   t) # checkout from tag
      export TAG=$OPTARG
      ;;
   g) # no git checkout needed
      GIT=
      ;;
   u) # need to update existing local git repository; implying -g
      UPDATE=1
      ;;
   h) # usage
      usage
      exit
      ;;
   \?)# unrecognized option
      echo "Unrecognized option -$OPTARG"
      usage
      exit
      ;;
   esac
done

if [ -z "$MACHINE"  ]; then
  echo "  == WARN == == WARN == == WARN == == WARN == == WARN == "
  echo "  == WARN == No machine was selected - exiting ..."
  echo "  == WARN == Use \"-m\" <machine name> option"
  echo "  == WARN == == WARN == == WARN == == WARN == == WARN == "
  exit 0
fi

if [ -n "$UPDATE" ]; then
   GIT=
fi

#if [ -d "$DEST/$MACHINE" ]; then
#   rm -rf $DEST/$MACHINE
#fi

mkdir -p $BUILD_WORK
cd $BUILD_WORK
if [ -n "$GIT" ]; then
   if [ -d 'E-4DWX' ]; then
      rm -rf E-4DWX
   fi
   git clone git@github.com:chengw00/E-4DWX.git 
fi

if [ -d 'E-4DWX' ]; then
   cd E-4DWX
   if [ -n "$UPDATE" ]; then
      git pull origin master
   fi
   if [ -n "$TAG" ]; then
      cd E-4DWX
      git checkout tags/$TAG
      if [ $? -ne 0 ]; then
          echo "Fatal: $TAG not valid for E-4DWX. Exiting ..."
         exit
      fi
   fi
else
   echo "Fatal: Path $BUILD_WORK/E-4DWX does not exist - exiting ..."
   exit
fi


MACHINE_PARAM_FILE=$BUILD_WORK/E-4DWX/build/${MACHINE}_params.sh
if [ -e $MACHINE_PARAM_FILE ];
then
  . $MACHINE_PARAM_FILE
else
  echo "  == WARN == No config file for $MACHINE found - exiting ...!"
  exit 0
fi

if [ -z "$MEMBER"  ]; then
  for MEMBER in $MEMBERS
  do
    export RANGE=$RANGES
    export MEMBER=$MEMBER
    echo "HERE"
    make clean
    make install
  done
else
  make clean
  make install
fi

#cd $DEST
#tar cvf $cwd/home_4dwx_${range}.tar .

exit
