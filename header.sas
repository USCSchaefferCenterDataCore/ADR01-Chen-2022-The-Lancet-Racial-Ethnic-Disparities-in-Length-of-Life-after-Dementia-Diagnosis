/* Fill in missing libnames */

%let rootpath=;
%let contentsdir=;
%let datalib=;
%let fmtlib=;
%let maclib=;
%let demogv=2017;
%let demogvq=2019;

%let harmdata=;
libname hrrxw "&harmdata./HRR";
libname enrffs "&harmdata./Enroll_Periods";
libname fdb "&harmdata.";

libname out "&rootpath./AD/ad_incidence_methods/";
%let oublib=out;

libname temp "&rootpath./AD/Data/TempWork";
%let tempwork=temp;

libname base "&rootpath./AD/Data/base/";
