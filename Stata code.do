/**********************************************************************
     
Purpose: Preparing and analyzing student test data

Author:  Tanya Sethi
***********************************************************************/

clear all
set more off
version 13.0

local ROOT "/Users/tanyasethi/Dropbox/Stata"
local DATA "`ROOT'"
local OUTPUT "`ROOT'/Output"
local sections w_correct s_correct a1_correct a2_correct a3_correct /// 
a4_correct a5_correct a6_correct a7_correct a8_correct spelling_correct

/**********************************************************************
                   Section 1: Data Preparation*
***********************************************************************/


* Importing student test data 
insheet using "`DATA'/student_test_data.csv", clear

* Recoding arithmetic scores from strings to integers 
forvalues x = 1/8 {
replace a`x'_correct = "0" if  a`x'_correct == "NONE"
destring a`x'_correct, replace 
}

* Treating missing values in word reading and sentence reading sections 
//Correcting erroneous entry of -98 in word reading section 
foreach x in correct incorrect missing {
replace w_`x' = -99 if w_`x' == -98
} 
//Saving missing values of the sections in a separate dta file 
savesome if w_correct ==-99| w_incorrect==-99| w_missing == -99 | ///
s_correct ==-99 | s_incorrect == -99 | s_missing == -99 using ///
"`OUTPUT'/students_reading_missing_marks", replace 
//Dropping missing values of the sections 
drop if w_correct ==-99| w_incorrect==-99| w_missing == -99 | /// 
s_correct ==-99 | s_incorrect == -99 | s_missing == -99 
 
* Identifying and treating errors, missing values and outliers
//Checking for duplicates 
duplicates list //no duplicates found in the current dataset
duplicates list  pupilid schoolid //no duplicates 

//Saving missing values of arithmetic section in a separate dta file 
//and dropping them from this dataset 
savesome if a1_correct ==.| a2_correct ==.|a3_correct ==.|a4_correct ==.| /// 
a5_correct ==.| a6_correct ==.  using ///
"`OUTPUT'/students_arithmetic_missing_marks", replace 
drop if a1_correct ==.| a2_correct ==.|a3_correct ==.|a4_correct ==.| /// 
a5_correct ==.| a6_correct ==.| a7_correct==.| a8_correct==.

//Saving missing values of spelling section in a separate dta file 
//and dropping them from this dataset 
savesome if spelling_correct==. using ///
"`OUTPUT'/students_spelling_missing_marks", replace
drop if spelling_correct==.

//Detecting and dropping outliers
/*Outliers are assumed to lie more than 3 standard-deviation from the variable's 
mean*/
gen outlier=0
foreach y of local sections {
qui su `y'
replace outlier=1 if abs((`y'-r(mean))/r(sd))>3 
}
drop if outlier==1 // 172 of 5507 observations identified as outliers
drop outlier

* Encoding zone as a numeric variable 
//zone var is a string, required in numeric for regressions
encode zone, generate(x) 
 
* Generating total testscore variable 
egen tot_score = rowtotal (`sections')

* Generating grade variable and labelling values 
gen grade=1
replace grade = 2 if tot_score >= 60 & tot_score <=79
replace grade = 3 if tot_score >= 40 & tot_score <=59
replace grade = 4 if tot_score >= 20 & tot_score <=39
replace grade = 5 if tot_score < 20
label define letter_grade 1 "A" 2 "B" 3 "C" 4 "D" 5 "F" 
label values grade letter_grade

* Standardisation of total test scores 
gen nt_score = tot_score if tracking ==0 //Score of control group students 
qui su nt_score 
gen tot_score_std= (tot_score - r(mean))/r(sd) /*Standarising total score of 
students with mean and S.D. of control group students*/
drop nt_score 

* Labelling standardised score variable 
label var tot_score_std "Total Standardized Test Score"

* Saving the data
save "`OUTPUT'/students_test_data.dta", replace 

* Opening teacher_data 
use "`DATA'/teacher_data", clear

*Treating missing values and outliers 
/*Outliers are assumed to lie more than 3 standard-deviation from the variable's 
mean*/
drop if yrstaught==.
qui su yrstaught
gen outlier=1 if abs((yrstaught-r(mean))/r(sd))>3 & !missing(yrstaught) 
drop if outlier==1 // no outliers detected 
drop outlier 

* Generating avg number of teaching experience by school 
/*Generating a new var that takes value=1 for a schoolid if yrstaught=. for any 
of its teachers*/
bysort schoolid: egen yrsmissing = max(missing(yrstaught)) 
/*Generating avg number of teaching experience by school if none of the values
for its teachers are missing*/
bysort schoolid: egen avg_exp_school = mean(yrstaught) if yrsmissing==0
drop yrsmissing

* reshaping data 
reshape wide yrstaught, i(schoolid) j(teacherid)

* Merging data 
merge 1:m schoolid using "`OUTPUT'/students_test_data.dta", nogen 

* Saving final dataset 
save "`OUTPUT'/final_dataset.dta", replace 

/**********************************************************************
                       Section 2: Analysis
***********************************************************************/

* Regression Specification 1
//standard errors clustered at the school level
qui eststo: reg tot_score_std tracking i.x, vce(cluster schoolid) 

* Regression Specification 2
qui eststo: reg tot_score_std tracking i.x girl avg_exp_school, vce(cluster schoolid)

* Exporting regression estimates in an excel file 
esttab using "`OUTPUT'/reg_estimates.csv", se ar2 noconstant drop(*.x) label ///
title(Regression Estimates) replace
eststo clear 

* Bar Graph
graph bar (mean) tot_score, over(tracking) over(district) outergap(50) ytitle ///
("Average student score out of 98") title("Average score of students") ///
subtitle ("across non-tracking and tracking schools in two districts") ///
bargap(0) asyvars bar(1, color(blue*2)) bar(2, color(orange*0.8)) ///
legend(label (1 "Non-Tracking") label(2 "Tracking")) blabel(total, ///
position(inside) format(%9.2f) color(white)) ///
note("Randomized experiment ran in 121 schools of two districts of Kenya in 2005-07.") ///
graphregion(color(white)) bgcolor(white)
graph export "`OUTPUT'/bargraph.png", replace
 
 
