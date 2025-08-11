TITLE BK Ca 2+ -activated K + channel
: Calcium activated K channel.
COMMENT
 Starting from the formulation in De Schutter and Bower, 1994, we
reduced the Ca 2+ dependent activation time to half to account for the larger slow repolarisation at
depolarised states.
Current Model Reference: Karima Ait Ouares , Luiza Filipis , Alexandra Tzilivaki , Panayiota Poirazi , Marco Canepari (2018) Two distinct sets of Ca 2+ and K + channels 
are activated at different membrane potential by the climbing fibre synaptic potential in Purkinje neuron dendrites. 
Kinetics were fit to data from Filipis et al. 2022
PubMed link: 

Contact: Filipis Luiza (luiza.filipis@univ-grenoble-alpes.fr)

ENDCOMMENT

UNITS {
	(molar) = (1/liter)
}

UNITS {
	(mV) =	(millivolt)
	(mA) =	(milliamp)
	(mM) =	(millimolar)
}


INDEPENDENT {t FROM 0 TO 1 WITH 1 (ms)}

NEURON {
	SUFFIX bks
	USEION lca READ lcai
USEION nca READ ncai
USEION tca READ tcai
	USEION k READ ek WRITE ik
	RANGE gkbar,gk,zinf,ik, minf
	GLOBAL bkcoef,bkexp,cahco, carco,tin, tinsh, calco
}


PARAMETER {
	celsius=37	(degC)
	v		(mV)
	gkbar=.08	(mho/cm2)	: Maximum Permeability
	 ncai 	(mM)
	 lcai (mM)
	 tcai (mM)

	ek  	(mV)
	dt		(ms)
	tin=0.02
	bkcoef=0.023
	bkexp=7.5
	cahco=1
	carco=0
	calco=1
	tinsh=400
}


ASSIGNED {
	ik		(mA/cm2)
	minf
	mexp
	zinf
	zexp
	gk
}

STATE {	m z }		: fraction of open channels

BREAKPOINT {
	SOLVE state
:	gk = gkbar*1000*m*z*z
	ik = gkbar*1000*m*z*z*(v - ek)
}
:UNITSOFF
:LOCAL fac

:if state_cagk is called from hoc, garbage or segmentation violation will
:result because range variables won't have correct pointer.  This is because
: only BREAKPOINT sets up the correct pointers to range variables.
PROCEDURE state() {	: exact when v held constant; integrates over dt step
	rate(v, lcai,ncai,tcai)
	m = m + mexp*(minf - m)
	z = z + zexp*(zinf - z)
	VERBATIM
	return 0;
	ENDVERBATIM
}

INITIAL {
	rate(v, lcai,ncai, tcai)
	m = minf
	z = zinf
}

FUNCTION alp(v (mV), lcai (mM), ncai (mM), tcai(mM)) (1/ms) { :callable from hoc
	alp = 0.4/((lcai*calco+ncai*cahco+tcai*carco))
}


FUNCTION bet(v (mV)) (1/ms) { :callable from hoc
	bet = 0.11/exp((v-55)/14.9)
}

PROCEDURE rate(v (mV), lcai (mM),ncai (mM), tcai (mM)) { :callable from hoc
	LOCAL a,b,tinca
	a = alp(v,lcai,ncai, tcai)
	zinf = 1/(1+a)
	:printf("zinf=%15.10g a=%15.10g\n",zinf,a)
	zexp = (1 - exp(-dt/4))
	b = bet(v)
	:minf = 8.5/(7.5+b)
	minf = 1/(1+b)
	mexp = (1 - exp(-dt*(bkexp+b)))
}
:UNITSON
