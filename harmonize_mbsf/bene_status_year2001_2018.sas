/* bene_status_year.sas
   make a file of beneficiary status by year
   Flags for AB enrollment, HMO status, dual eligibility,
     whether died this year, Part D plan,
     LIS status, RDS status, consistent with bene_status_month file
   Keep flags on whether enrolled AB all year, HMO all yr, FFS allyr,
     whether creditable coverage. Also whether rds/dual/lis all year.
   Also keep gender, birthdate, deathdate, age at beg of year and July 1st.
   
   SAMPLE: all benes on denominator or bsf, no duplicates,
           and did not die in a prior year according to the death date.
   Level of observation: bene_id, year
   
   Input files: denall[yyyy] or bsfall[yyyy]
   Output files: bene_status_year[yyyy]
   
   Feb 20, 2014, p. st.clair
   March 14, 2014, p.st.clair: added merge with cleaned bene_demog file
        switched to using birth_date/death_date from bene_demog
   July 2, 2014, p. st.clair: correct missing year variable from 2009-2011,
                              add egwp status, and drop benes with dropflag=Y. 
   October 30, 2014, p. st.clair: generalized for transition to DUA 25731
	 Feb 14, 2018, p. ferido: adapted for the VRDC
*/

options compress=yes nocenter ls=150 ps=200 replace errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
	
%include "../vrdc_header.sas";

***** Setting min and max years;
%let minyr=2001;
%let maxyr=2018;

***** Macro for contents - change contentsdir;

%macro sascontents(fn,lib=work,contdir=,opt=position,domeans=N);
   proc printto print="&contdir.&fn..contents.txt" new;
   proc contents data=&lib..&fn &opt;
   run;
   %if %upcase(&domeans)=Y %then %do;
       proc means data=&lib..&fn;
       run;
   %end;
   proc printto;
   run;
%mend;

***** Proc formats;

proc format;
	%include "&fmtlib.bene_status.fmt";
	%include "&fmtlib.p2egwp.fmt";
run;

***** Statyr Macro
   summarizes bene status/enrollment for single years.
   parameters:
   - byr,eyr = range of years to process (4 digit)
   - hmo_mo = name of the variable on mbsf with # hmo months
   - hmoind = name of the monthly hmo indicators (hmoind1-hmoind12)
   - hmonm  = whether there is a leading zero for months < 10. If =0 yes, if null, no
   - stbuy  = name of monthly state buyin flags (buyin or entitl)
   - denbsf = prefix for the denom/bsf file. By default is mbsf_abcd_
   - denfile = name of the denom/bsf file if not mbsf_abcd_yyyy
   - denlib  = libname for location of denom/bsf file
   - bdt, ddt = name of variables for birth and death date
   - rec     = reason for entitlement code variable on den/bsf (e.g., entlmt_rsn_curr, entlmt_rsn_orig)
   - esrd    = name of ESRD indicator variable on den/bsf
   - mscd    = name of the medicare status code variable on den/bsf - monthly code in VRDC, will use last month
   - demogyr = version of bene_demog[demogyr] to use. By default just bene_demog;

%include "&maclib./statyr.sas";

/* Uses the MBSF_AB files */
%statyr(2001,2005,hmo_mo=bene_hmo_cvrage_tot_mons,hmoind=beme_hmo_ind_,hmonm=0,
	stbuy=bene_mdcr_entlmt_buyin_ind_,stbuymo=bene_state_buyin_tot_mons,
	denbsf=mbsf_ab_,denfile=,denlib=mbsf,
	bdt=bene_birth_dt,ddt=bene_death_dt,rec=bene_entlmt_rsn_,esrd=bene_esrd_ind,
	mscd=bene_mdcr_status_cd,demogyr=2015);

/* Uses the MBSF_ABCD files */
%statyr(2006,2016,denlib=mbsf,demogyr=2015);
%statyr(2017,2017,denlib=mbsf,demogyr=2018);
%statyr(2018,2018,denlib=rifq2018,demogyr=2018);

