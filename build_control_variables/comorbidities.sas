/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Creating Data Set of Comorbidities to Merge on for Sample Characteristics;
* Input: mbsf_cc*;
* Output: adrd_cc;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=1999;
%Let maxyear=2017;

%macro cc;
%do year=&minyear %to &maxyear;
data &tempwork..bsfcc&year;
	set mbsf.mbsf_cc_&year;
	by bene_id;
	if first.bene_id;
run;
%end;

data &outlib..cc9917;
	merge
	%do year=&minyear %to &maxyear;
	&tempwork..bsfcc&year (rename=(alzh_demen_ever=alzh_demen_ever&year alzh_ever=alzh_ever&year ami_ever=ami_ever&year anemia_ever=anemia_ever&year
	asthma_ever=asthma_ever&year atrial_fib_ever=atrial_fib_ever&year cancer_breast_ever=cancer_breast_ever&year
	cancer_colorectal_ever=cancer_colorectal_ever&year cancer_endometrial_ever=cancer_endometrial_ever&year cancer_lung_ever=cancer_lung_ever&year
	cancer_prostate_ever=cancer_prostate_ever&year cataract_ever=cataract_ever&year chf_ever=chf_ever&year chronickidney_ever=chronickidney_ever&year
	copd_ever=copd_ever&year depression_ever=depression_ever&year diabetes_ever=diabetes_ever&year glaucoma_ever=glaucoma_ever&year
	hip_fracture_ever=hip_fracture_ever&year hyperl_ever=hyperl_ever&year hyperp_ever=hyperp_ever&year hypert_ever=hypert_Ever&year
	hypoth_ever=hypoth_ever&year ischemicheart_ever=ischemicheart_ever&year osteoporosis_ever=osteoporosis_ever&year
	ra_oa_ever=ra_oa_ever&year stroke_tia_ever=stroke_tia_ever&year))
	%end;;
	by bene_id;
	alzh_demen_ever=min(of alzh_demen_ever&minyear-alzh_demen_ever&maxyear);
	alzh_ever=min(of alzh_ever&minyear-alzh_ever&maxyear);
	ami_ever=min(of ami_ever&minyear-ami_ever&maxyear);
	anemia_ever=min(of anemia_ever&minyear-anemia_ever&maxyear);
	asthma_ever=min(of asthma_ever&minyear-asthma_ever&maxyear);
	atrial_fib_ever=min(of atrial_fib_ever&minyear-atrial_fib_ever&maxyear);
	cancer_breast_ever=min(of cancer_breast_ever&minyear-cancer_breast_ever&maxyear);
	cancer_colorectal_ever=min(of cancer_colorectal_ever&minyear-cancer_colorectal_ever&maxyear);
	cancer_endometrial_ever=min(of cancer_endometrial_ever&minyear-cancer_endometrial_ever&maxyear);
	cancer_lung_ever=min(of cancer_lung_ever&minyear-cancer_lung_ever&maxyear);
	cancer_prostate_ever=min(of cancer_prostate_ever&minyear-cancer_prostate_ever&maxyear);
	cataract_ever=min(of cataract_ever&minyear-cataract_ever&maxyear);
	chf_ever=min(of chf_ever&minyear-chf_ever&maxyear);
	chronickidney_ever=min(of chronickidney_ever&minyear-chronickidney_ever&maxyear);
	copd_ever=min(of copd_ever&minyear-copd_ever&maxyear);
	depression_ever=min(of depression_ever&minyear-depression_ever&maxyear);
	diabetes_ever=min(of diabetes_ever&minyear-diabetes_ever&maxyear);
	glaucoma_ever=min(of glaucoma_ever&minyear-glaucoma_ever&maxyear);
	hip_fracture_ever=min(of hip_fracture_ever&minyear-hip_fracture_ever&maxyear);
	hyperl_ever=min(of hyperl_ever&minyear-hyperl_ever&maxyear);
	hyperp_ever=min(of hyperp_ever&minyear-hyperp_ever&maxyear);
	hypert_ever=min(of hypert_ever&minyear-hypert_ever&maxyear);
	hypoth_ever=min(of hypoth_ever&minyear-hypoth_ever&maxyear);
	ischemicheart_ever=min(of ischemicheart_ever&minyear-ischemicheart_ever&maxyear);
	osteoporosis_ever=min(of osteoporosis_ever&minyear-osteoporosis_ever&maxyear);
	ra_oa_ever=min(of ra_oa_ever&minyear-ra_oa_ever&maxyear);
	stroke_tia_ever=min(of stroke_tia_ever&minyear-stroke_tia_ever&maxyear);
	format alzh_demen_ever alzh_ever ami_ever anemia_ever asthma_ever atrial_fib_ever cancer_breast_ever
	cancer_colorectal_ever cancer_endometrial_ever cancer_lung_ever cancer_prostate_ever cataract_ever
	chf_ever chronickidney_ever copd_ever depression_ever diabetes_ever glaucoma_ever hip_fracture_ever
	hyperl_ever hyperp_ever hypert_ever hypoth_ever ischemicheart_ever osteoporosis_ever ra_oa_ever
	stroke_tia_ever mmddyy10.;
	keep  bene_id alzh_demen_ever alzh_ever ami_ever anemia_ever asthma_ever atrial_fib_ever cancer_breast_ever
	cancer_colorectal_ever cancer_endometrial_ever cancer_lung_ever cancer_prostate_ever cataract_ever
	chf_ever chronickidney_ever copd_ever depression_ever diabetes_ever glaucoma_ever hip_fracture_ever
	hyperl_ever hyperp_ever hypert_ever hypoth_ever ischemicheart_ever osteoporosis_ever ra_oa_ever
	stroke_tia_ever;
run;
%mend;

%cc;




