#!/usr/bin/perl
  
# Follow the below conventions for component name and structure
#
# %MODULES = ( LOAD => {
#                 PRE_F => ['a','b'],
#                 MODEL => ['c','d'],
#                 POSTPROC => ['e','f'],
#                 VERI => ['g'];
#                 GBC => ['h'];
#                 PRE_P => ['g','h'],
#                 ANEN => ['i','j'],
#                 CLEAN => ['k'],
#            },
#              SWAP => {
#                 PRE_F => ['x'],
#                 MODEL => ['y','z','o:n']   # In the case where ':' exists, it means swapping out o(ld) with n(ew) module
#            },
#          );
#
# Call out NETCDF module here
use lib "$ENV{MODULESHOME}/init";
use perl;

@MODULE_USE = "$ENV{BASE_DIR}/$ENV{LOGNAME}/opt/my_modules";

%MODULES = ( LOAD => {
                       PRE_F => ['costinit','compiler/intel','python_atec','perl_atec','netcdf_atec'],
                       PRE_P => ['costinit','compiler/intel','python_atec','perl_atec','netcdf_atec'],
                       POSTPROC => ['compiler/intel','ncl_atec','scrub_atec','python_atec','perl_atec','netcdf_atec'],
                       VERI => ['compiler/intel','gmt_atec','python_atec','perl_atec','netcdf_atec'],
                       MODEL => ['compiler/intel','netcdf_atec'],
                       ANEN => ['compiler/intel','ncl_atec','python_atec','perl_atec'],
                       CLEAN => ['compiler/intel','python_atec'],
             },
             SWAP => {
             },
           ); 

1;
