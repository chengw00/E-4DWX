###########################################################################
#
# Makefile for GMODJOBS
#
# RSR 4/15/2019
#
#       
###########################################################################

# --------- Definitions ----------
# TARGET_DIR: where the files and directories are installed.
#             TARGET_DIR can be overridden on the command line, if
#             not overridden on the command line the default below is used.

TARGET_DIR=$(DEST)/$(MACHINE)/$(RANGE)/$(MEMBER)

# Include the standard shared make info (make_defns)
include $(PWD)/build/make_defns

# ------------ Targets --------------
# For reference

TARGETS=all clean install

all:		
	echo "No compile needed"

clean: FORCE
	$(RM) $(TARGET_DIR)

install: dir FORCE
	files=`ls ./common` ;\
	for file in $${files} ; do \
		$(CPR) ./common/$${file} $(TARGET_DIR) ;\
	done

	files=`ls ./version/$(VERSION)` ;\
	for file in $${files} ; do \
		$(CPR) ./version/$(VERSION)/$${file} $(TARGET_DIR) ;\
	done

	files=`ls ./machine/$(MACHINE)` ;\
	for file in $${files} ; do \
		$(CPR) ./machine/$(MACHINE)/$${file} $(TARGET_DIR) ;\
	done
	files=`ls ./members/$(RANGE)/` ;\
	for file in $${files} ; do \
		$(CPR) ./members/$(RANGE)/$${file} $(TARGET_DIR) ;\
	done

	cd $(TARGET_DIR)  ;\
	sed -e "s&SEDBASEDIR&$(BASEDIR)&g" -e "s&SEDMPICMDBINDIR&${MPICMD}&g" sed.flexinput.job.pm > flexinput.job.pm && $(RM) sed.flexinput.job.pm ;\

	cd $(TARGET_DIR)  ;\
	sed -e "s&SEDBASEDIR&$(BASEDIR)&g" -e "s&SEDDOTARSUMFORDISTRIB&${DO_TAR_SUM_FOR_DISTRIB}&g" sed.postprocinput.pl > postprocinput.pl && $(RM) sed.postprocinput.pl ;\

	cd $(TARGET_DIR)/scripts  ;\
	sed -e "s&SEDRANGE&$(RANGE)&g" -e "s&SEDBASEDIR&$(BASEDIR)&g" -e "s&SEDVERSION&${VERSION}&g" -e "s&SEDACCOUNTKEY&${ACCOUNT_KEY}&g" -e "s&SEDQUEUE&${QUEUE}&g" -e "s&SEDDSP&${DSP}&g"  sed.env_vars.csh > env_vars.csh && $(RM) sed.env_vars.csh ;\

	cd $(TARGET_DIR)/config  ;\
	files=`ls *cfg` ;\
	for file in $${files} ; do \
		sed -e "s&SEDPATH&$(BASEDIR)/$(USER)&g" $${file} > `echo $${file} | cut -c5-` && $(RM) $${file} ;\
	done

	cd $(TARGET_DIR)  ;\
	dirs="logs tmp" ;\
	for dir in $${dirs} ; do \
		$(MKDIR) $${dir} ;\
	done

dir:
	if test -d $(TARGET_DIR) ;\
	then \
		: ;\
	else \
		mkdir -p $(TARGET_DIR) ;\
	fi

FORCE:

# -----------------------------------------------------

# This needs to come after the other make targets

# DO NOT DELETE THIS LINE -- make depend depends on it.
