/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Creating Data Set of Comorbidities to Merge on for Sample Characteristics;
* Input: mbsf_otcc*;
* Output: otcc;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2000;
%Let maxyear=2017;

%macro otcc_2000;

%do year=&minyear %to &maxyear;
data temp.otcc&year;
	set mbsf.mbsf_otcc_&year;
	by bene_id;
	if first.bene_id;
run;
%end;

data base.otcc0017;
	merge
	%do year=&minyear %to &maxyear;
	temp.otcc&year (rename=(acp_medicare_ever=acp_medicare_ever&year alco_medicare_ever=alco_medicare_ever&year anxi_medicare_ever=anxi_medicare_ever&year 
	autism_medicare_ever=autism_medicare_ever&year bipl_medicare_ever=bipl_medicare_ever&year brainj_medicare_ever=brainj_medicare_ever&year cerpal_medicare_ever=cerpal_medicare_ever&year
	cysfib_medicare_ever=cysfib_medicare_ever&year depsn_medicare_ever=depsn_medicare_ever&year epilep_medicare_ever=epilep_medicare_ever&year
	fibro_medicare_ever=fibro_medicare_ever&year hearim_medicare_ever=hearim_medicare_ever&year hepviral_medicare_ever=hepviral_medicare_ever&year 
	hivaids_medicare_ever=hivaids_medicare_ever&year intdis_medicare_ever=intdis_medicare_ever&year 
	leadis_medicare_ever=leadis_medicare_ever&year leuklymph_medicare_ever=leuklymph_medicare_ever&year liver_medicare_ever=liver_medicare_ever&year
	migraine_medicare_ever=migraine_medicare_ever&year mobimp_medicare_ever=mobimp_medicare_ever&year mulscl_medicare_ever=mulscl_medicare_ever&year 
	musdys_medicare_ever=musdys_medicare_ever&year obesity_medicare_ever=obesity_medicare_ever&year 
	othdel_medicare_ever=othdel_medicare_ever&year oud_any_medicare_ever=oud_any_medicare_ever&year
	oud_dx_medicare_ever=oud_dx_medicare_ever&year oud_hosp_medicare_ever=oud_hosp_medicare_ever&year
	oud_mat_medicare_ever=oud_mat_medicare_ever&year psds_medicare_ever=psds_medicare_ever&year
	ptra_medicare_ever=ptra_medicare_ever&year pvd_medicare_ever=pvd_medicare_ever&year schi_medicare_ever=schi_medicare_ever&year
	schiot_medicare_ever=schiot_medicare_ever&year spibif_medicare_ever=spibif_medicare_ever&year
	spiinj_medicare_ever=spiinj_medicare_ever&year toba_medicare_ever=toba_medicare_ever&year ulcers_medicare_ever=ulcers_medicare_ever&year
	visual_medicare_ever=visual_medicare_ever&year) keep=acp_medicare_ever alco_medicare_ever anxi_medicare_ever 
	autism_medicare_ever bipl_medicare_ever brainj_medicare_ever cerpal_medicare_ever
	cysfib_medicare_ever depsn_medicare_ever epilep_medicare_ever
	fibro_medicare_ever hearim_medicare_ever hepviral_medicare_ever 
	hivaids_medicare_ever intdis_medicare_ever leadis_medicare_ever 
	leuklymph_medicare_ever liver_medicare_ever migraine_medicare_ever
	mobimp_medicare_ever mulscl_medicare_ever
	musdys_medicare_ever obesity_medicare_ever 
	othdel_medicare_ever oud_any_medicare_ever
	oud_dx_medicare_ever oud_hosp_medicare_ever
	oud_mat_medicare_ever psds_medicare_ever
	ptra_medicare_ever pvd_medicare_ever schi_medicare_ever
	schiot_medicare_ever spibif_medicare_ever
	spiinj_medicare_ever toba_medicare_ever ulcers_medicare_ever
	visual_medicare_ever bene_id)
	%end;;
	by bene_id;
	acp_medicare_ever=min(of acp_medicare_ever&minyear.-acp_medicare_ever&maxyear.);
	alco_medicare_ever=min(of alco_medicare_ever&minyear.-alco_medicare_ever&maxyear.);
	anxi_medicare_ever=min(of anxi_medicare_ever&minyear.-anxi_medicare_ever&maxyear.);
	autism_medicare_ever=min(of autism_medicare_ever&minyear.-autism_medicare_ever&maxyear.);
	bipl_medicare_ever=min(of bipl_medicare_ever&minyear.-bipl_medicare_ever&maxyear.);
	brainj_medicare_ever=min(of brainj_medicare_ever&minyear.-brainj_medicare_ever&maxyear.);
	cerpal_medicare_ever=min(of cerpal_medicare_ever&minyear.-cerpal_medicare_ever&maxyear.);
	cysfib_medicare_ever=min(of cysfib_medicare_ever&minyear.-cysfib_medicare_ever&maxyear.);
	depsn_medicare_ever=min(of depsn_medicare_ever&minyear.-depsn_medicare_ever&maxyear.);
	epilep_medicare_ever=min(of epilep_medicare_ever&minyear.-epilep_medicare_ever&maxyear.);
	fibro_medicare_ever=min(of fibro_medicare_ever&minyear.-fibro_medicare_ever&maxyear.);
	hearim_medicare_ever=min(of hearim_medicare_ever&minyear.-hearim_medicare_ever&maxyear.);
	hepviral_medicare_ever=min(of hepviral_medicare_ever&minyear.-hepviral_medicare_ever&maxyear.);
	hivaids_medicare_ever=min(of hivaids_medicare_ever&minyear.-hivaids_medicare_ever&maxyear.);
	intdis_medicare_ever=min(of intdis_medicare_ever&minyear.-intdis_medicare_ever&maxyear.);
	leadis_medicare_ever=min(of leadis_medicare_ever&minyear.-leadis_medicare_ever&maxyear.);
	leuklymph_medicare_ever=min(of leuklymph_medicare_ever&minyear.-leuklymph_medicare_ever&maxyear.);
	liver_medicare_ever=min(of liver_medicare_ever&minyear.-liver_medicare_ever&maxyear.);
	migraine_medicare_ever=min(of migraine_medicare_ever&minyear.-migraine_medicare_ever&maxyear.);
	mobimp_medicare_ever=min(of mobimp_medicare_ever&minyear.-mobimp_medicare_ever&maxyear.);
	mulscl_medicare_ever=min(of mulscl_medicare_ever&minyear.-mulscl_medicare_ever&maxyear.);
	musdys_medicare_ever=min(of musdys_medicare_ever&minyear.-musdys_medicare_ever&maxyear.);
	obesity_medicare_ever=min(of obesity_medicare_ever&minyear.-obesity_medicare_ever&maxyear.);
	othdel_medicare_ever=min(of othdel_medicare_ever&minyear.-othdel_medicare_ever&maxyear.);
	oud_any_medicare_ever=min(of oud_any_medicare_ever&minyear.-oud_any_medicare_ever&maxyear.);
	oud_dx_medicare_ever=min(of oud_dx_medicare_ever&minyear.-oud_dx_medicare_ever&maxyear.);
	oud_hosp_medicare_ever=min(of oud_hosp_medicare_ever&minyear.-oud_hosp_medicare_ever&maxyear.);
	oud_mat_medicare_ever=min(of oud_mat_medicare_ever&minyear.-oud_mat_medicare_ever&maxyear.);
	psds_medicare_ever=min(of psds_medicare_ever&minyear.-psds_medicare_ever&maxyear.);
	ptra_medicare_ever=min(of ptra_medicare_ever&minyear.-ptra_medicare_ever&maxyear.);
	pvd_medicare_ever=min(of pvd_medicare_ever&minyear.-pvd_medicare_ever&maxyear.);
	schi_medicare_ever=min(of schi_medicare_ever&minyear.-schi_medicare_ever&maxyear.);
	schiot_medicare_ever=min(of schiot_medicare_ever&minyear.-schiot_medicare_ever&maxyear.);
	spibif_medicare_ever=min(of spibif_medicare_ever&minyear.-spibif_medicare_ever&maxyear.);
	spiinj_medicare_ever=min(of spiinj_medicare_ever&minyear.-spiinj_medicare_ever&maxyear.);
	toba_medicare_ever=min(of toba_medicare_ever&minyear.-toba_medicare_ever&maxyear.);
	ulcers_medicare_ever=min(of ulcers_medicare_ever&minyear.-ulcers_medicare_ever&maxyear.);
	visual_medicare_ever=min(of visual_medicare_ever&minyear.-visual_medicare_ever&maxyear.);
	format acp_medicare_ever alco_medicare_ever anxi_medicare_ever autism_medicare_ever bipl_medicare_ever brainj_medicare_ever cerpal_medicare_ever
	cysfib_medicare_ever depsn_medicare_ever epilep_medicare_ever fibro_medicare_ever hearim_medicare_ever
	hepviral_medicare_ever hivaids_medicare_ever intdis_medicare_ever leadis_medicare_ever leuklymph_medicare_ever liver_medicare_ever migraine_medicare_ever
	mobimp_medicare_ever mulscl_medicare_ever musdys_medicare_ever obesity_medicare_ever othdel_medicare_ever oud_any_medicare_ever oud_dx_medicare_ever
	oud_hosp_medicare_ever oud_mat_medicare_ever psds_medicare_ever ptra_medicare_ever pvd_medicare_ever schi_medicare_ever schiot_medicare_ever
	spibif_medicare_ever spiinj_medicare_ever toba_medicare_ever ulcers_medicare_ever visual_medicare_ever mmddyy10.;
	keep bene_id acp_medicare_ever alco_medicare_ever anxi_medicare_ever autism_medicare_ever bipl_medicare_ever brainj_medicare_ever cerpal_medicare_ever
	cysfib_medicare_ever depsn_medicare_ever epilep_medicare_ever fibro_medicare_ever hearim_medicare_ever
	hepviral_medicare_ever hivaids_medicare_ever intdis_medicare_ever leadis_medicare_ever leuklymph_medicare_ever liver_medicare_ever migraine_medicare_ever
	mobimp_medicare_ever mulscl_medicare_ever musdys_medicare_ever obesity_medicare_ever othdel_medicare_ever oud_any_medicare_ever oud_dx_medicare_ever
	oud_hosp_medicare_ever oud_mat_medicare_ever psds_medicare_ever ptra_medicare_ever pvd_medicare_ever schi_medicare_ever schiot_medicare_ever
	spibif_medicare_ever spiinj_medicare_ever toba_medicare_ever ulcers_medicare_ever visual_medicare_ever;
run;
%mend;

%otcc_2000;




