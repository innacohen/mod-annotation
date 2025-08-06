 COMMENT
Biexponential single synaptic activation that occurs at a user-specified time.
The conductance varies with membrane potential to emulate NMDA-gated conductance.

Based on syn_g.mod
ENDCOMMENT
					       
NEURON {
	POINT_PROCESS nmda
	RANGE onset, tau0, tau1, gmax, e, i, g
	NONSPECIFIC_CURRENT i
}

UNITS {
	(nA) = (nanoamp)
	(mV) = (millivolt)
	(umho) = (micromho)
}

PARAMETER {
	onset=2  (ms)
	tau0=3 (ms)
	tau1=90 (ms)
	gmax=0.000735	(umho)
	e=5	 (mV)
	v	 (mV)
	nmg = 0.3 (1) : eta*[Mg]o for eta = 0.25 (/mM) and [Mg]o = 1 mM
	  : 0.33 used in Polsky's glutamate.mod
	  : Zador et al. 1990 assumed eta = 0.33 (/mM)
	gamma = 0.08 (/mV) : .08 used in Polsky's glutamate.mod
	  : Zador et al. 1990 used 0.06 (/mV)
}

ASSIGNED { i (nA)  g (umho) }

LOCAL   a[2]
LOCAL   tpeak
LOCAL   adjust
LOCAL   amp

	BREAKPOINT {
	if (gmax) {
		at_time(onset) : tell integrator when g starts to change
		g = cond(t)
	}
	i = g*(v - e)
}

FUNCTION cond(x(ms))(umho) {
	tpeak=tau0*tau1*log(tau0/tau1)/(tau0-tau1)
	adjust=1/((1-exp(-tpeak/tau0))-(1-exp(-tpeak/tau1)))
	amp=adjust*gmax
	if (x < onset) {
		cond = 0
	}
		else {
		a[0]=1-exp(-(x-onset)/tau0)
		a[1]=1-exp(-(x-onset)/tau1)
:		cond = amp*(a[0]-a[1])
		cond = (amp*(a[0]-a[1])/(1 + nmg*exp(-gamma*(v))))
	}
}
