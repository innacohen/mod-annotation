COMMENT
//****************************//
// Created by Alon Polsky 	//
//    apmega@yahoo.com		//
//		2010			//
//****************************//
based on Sun et al 2006
Modified 2015 by Robert Egger
to include facilitation variable
as modeled by Varela et al. 1997
ENDCOMMENT
TITLE GABAA synapse activated by the network
NEURON {
	POINT_PROCESS gaba_syn
	NONSPECIFIC_CURRENT i
	RANGE i,ggaba
	RANGE risetime,decaytime,e 
}
PARAMETER {
	e= -75.0	(mV)
	risetime=0.5 	(ms)	:2
	decaytime=20    (ms)	:40
	v		(mV)
	}
ASSIGNED {
	i		(nA)  
	ggaba
    
}

STATE {
	R
	D
}

INITIAL {
	
    	R=0
	D=0
	ggaba=0
	}
BREAKPOINT {
	SOLVE state METHOD cnexp
	ggaba=D-R
	i=(1e-3)*ggaba*(v-e)
}
NET_RECEIVE(weight) {
    R = R + weight
    D = D + weight
    }
DERIVATIVE state {
	R'=-R/risetime
	D'=-D/decaytime
	
}
