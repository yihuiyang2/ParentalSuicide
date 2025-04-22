**
** Figure 4 irr and ird by week, compare mother to father
**

** Created by Yihui Yang, 2024-03-28

sysdir set PLUS "W:\C6_Fang\IT\STATA\plus\"
cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"


log using output/Figure4.log, text replace

**# IRR
* estimate IRR
foreach i of num 1/3{ 
	
* Import data
use "data/data`i'.dta", clear

*In the original dataset, the variable far has 1=father, 0=mother
*now create variable mot: 1=mother, 0=father
gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot

* Merge with data on spline
merge m:1 wk using "data/fig4_wksp`i'.dta"
drop _merge

*regression
poisson _d i.mot##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his, irr exp(fu)

*predict log IRR 
predictnl rr= _b[1.mot]+_b[1.mot#c.wksp1]*wksp1+_b[1.mot#c.wksp2]*wksp2+_b[1.mot#c.wksp3]*wksp3 if mot==1, ci(lb ub)

* save estimates
keep if mot == 1
keep mot wk rr lb ub
gen prd=`i'
save "output/figure4irr_`i'", replace
}


**
** visulize
**
* load estimates
clear
append using output/figure4irr_1 output/figure4irr_2 output/figure4irr_3


*collapse
collapse (first) rr lb ub, by(wk prd)

* exp 
replace rr = exp(rr)
replace lb = exp(lb)
replace ub = exp(ub)

* label
label define px 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd px

* exclusion
drop if prd==2 & wk>40 


* plot 
twoway ///
	(rarea lb ub wk, sort color(pink) fi(inten10) lw(none)) ///
	(scatter rr wk, msymbol(o) msize(tiny) mcolor(pink) fi(inten10) connect(direct) lcolor(red) sort), ///
by(prd, rows(1) legend(off) ixaxes iyaxes graphregion(color(white)) note("")) ///
yline(1, lp(-) lc(ltblue) lw(medthick)) ///
ytitle("Incidence rate ratio") ///
xtitle("") ///
xlabel(0(5)53) xsize(20) ysize(7) ///
saving(output/figure4irr,replace) 

**# IRD
** based on https://journals.sagepub.com/doi/pdf/10.1177/1536867X221106437
** Stata tip 146: Using margins after a Poisson regression model to estimate the number of events prevented by an intervention

clear
matrix X = J(1,5,.)


foreach i of num 1/3 {
		
* Import data
use "data/data`i'.dta", clear

gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot

* Merge with data on spline
merge m:1 wk using "data/fig4_wksp`i'.dta"
drop _merge

* model
poisson _d i.mot##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his, irr exp(fu)

* predict risk difference by week
foreach k of num 1/53 {
	preserve
	keep if wk==`k'
	
    count if mot==0 & e(sample)==1
    scalar r=r(N)
	
    if r > 0 {
    margins, at((asobs) _all) at(mot=1) exp(predict(n)*r) subpop(if mot==0) pwcompare level(95)
    mat t = r(table_vs)
    qui: sum(fu) if mot==0
    scalar p=r(sum)/1000

* extract RD
    matrix A = J(1,5,.)
	matrix A[1,1] = `i'
    matrix A[1,2] = `k'
    matrix A[1,3] = t[1,1]/p
    matrix A[1,4] = t[5,1]/p
    matrix A[1,5] = t[6,1]/p  
    
* save estimates
    matrix X = X \ A
  }
   restore
}
}


* output estimates
matrix colnames X = prd wk rd lb ub
clear
svmat X, names(col)
save output/Figure4ird, replace


**
** visualize
**

* input estimates
use output/Figure4ird, clear

* label
label define px 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd px

* exclusion
drop if prd==2 & wk>40 

replace rd=rd*365.25
replace lb=lb*365.25
replace ub=ub*365.25


* plot 
twoway ///
	(rarea lb ub wk, sort color(pink) lw(none) fi(inten10)) ///
	(scatter rd wk, msymbol(o) msize(tiny) mcolor(pink) fi(inten10) connect(direct) lcolor(red) sort), ///
by(prd, rows(1) legend(off) ixaxes iyaxes graphregion(color(white)) note("")) ///
yline(0, lp(-) lc(ltblue) lw(medthick)) ///
ytitle("Incidence rate difference" "per 1000 person years") ///
xtitle("Week") ///
xlabel(0(5)53) xsize(20) ysize(7) ///
saving(output/figure4ird,replace) 



*Merge Figure on irr and ird
grc1leg "output/figure4irr.gph" "output/figure4ird.gph", rows(2) imargin(1 1 1 1) ///
graphregion(color(white)) ///
ring(2) ///
xsize(70) ysize(100) ///
saving("output/figure4",replace)  

* output
graph use output/figure4
graph export output/figure4.jpg, replace


log close
