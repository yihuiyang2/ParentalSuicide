**
** Figure 2 IR of suicide attempt by week
**

** Created by Yihui Yang, 2024-04-01


cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"


log using output/Figure2.log, text replace


matrix X = J(1, 6,.)

foreach i of num 1/3 {
		
* Import data
use "data/data`i'.dta", clear

 foreach j of num 0/1 {
 	
	preserve
	keep if far==`j'
	
gen py=round(fu/365.25)
	

* sum up events and person-time
collapse (sum) _d py, by(agec cal wk)


* direct standardization
qui:dstdize _d py agec cal, by(wk) using(data/stdpop2)
  matrix ir = r(adj)
  matrix ub = r(ub) 
  matrix lb = r(lb)
 
* extract SIR     
  matrix A = J(53, 6,.)
  
  levelsof wk, local(lvl) 
  
 
 foreach k of local lvl { 
   matrix A[`k',1] = `i' 
   matrix A[`k',2] = `j'
   matrix A[`k',3] = `k'
   matrix A[`k',4] = ir[1,`k']*1000
   matrix A[`k',5] = lb[1,`k']*1000
   matrix A[`k',6] = ub[1,`k']*1000
 } 
 
  mat X = X\A	
  restore
 }  

}  

matrix colnames X=prd far wk ir lb ub

clear
svmat X, names(col)
save output/figure2, replace

**
** visulize
**

use output/figure2, clear

* label phase
label define prdlab 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd prdlab

*drop observations
drop if  ir==9000 | ir==.
drop if prd==2 & wk>40 

*generate smoothed ci using lowess
foreach i of num 0/1 {
	foreach j of num 1/3{
		
		lowess lb wk if far==`i' & prd==`j', gen(lbs`i'`j') nograph
        lowess ub wk if far==`i' & prd==`j', gen(ubs`i'`j') nograph
        lowess ir wk if far==`i' & prd==`j', nograph gen(irs`i'`j')

		}
}

gen lbs=min(lbs01,lbs02,lbs03,lbs11,lbs12,lbs13)
gen ubs=min(ubs01,ubs02,ubs03,ubs11,ubs12,ubs13)
gen irs=min(irs01,irs02,irs03,irs11,irs12,irs13)



* plot
twoway ///
	(rarea lbs ubs wk if far==0 , color(pink) lw(none) fi(inten10)) ///
	(rarea lbs ubs wk if far==1 , color(ltblue) lw(none) fi(inten20)) ///
    (scatter ir wk if far==0 , msymbol(O) mcolor(red) sort) /// 
	(line irs wk if far==0 , color(pink)  fi(inten10)) ///
	(scatter ir wk if far==1 , msymbol(O) mcolor(midblue) sort) ///
	(line irs wk if far==1 , color(navy)  fi(inten10)), ///
by(prd, rows(1) ixaxes iyaxes graphregion(color(white)) note("") legend(position(6))) ///
legend(order(4 6) lab(4 "Mothers") lab (6 "Fathers") rows(1) region(lcolor(white)) size(vsmall)) graphregion(color(white)) ///
xlabel(0(5)52) xsize(20) ysize(7) ///
ytitle("Standardized incidence rate (1000 person-years)",size(small)) ///
xtitle("Week",size(small)) ///
saving(output/figure2,replace) 



* output
graph use output/figure2
graph export output/figure2.jpg, replace

* log close

