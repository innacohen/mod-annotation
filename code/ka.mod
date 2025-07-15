TITLE the transient, outward potassium current
COMMENT
change it to Connor-Stevens model
ENDCOMMENT

UNITS {
	(S) = (siemens)
	(mV) = (millivolt)
	(mA) = (milliamp)
}

NEURON {
    SUFFIX ka
    USEION k READ ko WRITE ik
    RANGE gmax,ik, q10
    THREADSAFE
}

CONSTANT {
	FARADAY = 96485.3399
	R = 8.31447215
}

PARAMETER {
	k_i = 140
    gmax = 0.005 (S/cm2)
	Ekd1 = -70 (mV)
	q10 = 1
}

ASSIGNED {
    v (mV)
    ko

    ek1 (mV)
    ik (mA/cm2)
	ek
	m_inf
	tau_m
	h_inf
	tau_h
	qt
	celsius (degC)
}

STATE {
    m h
}

BREAKPOINT {
    SOLVE states METHOD cnexp
:	ek1 = (1e3) * (R*(celsius+273.15))/(FARADAY) * log (ko/k_i)
    ik = gmax*m*m*m*h*(v-Ekd1)

}

INITIAL {
	settables(v)
	
    m = m_inf
    h = h_inf
    qt = q10^((celsius-6.3 (degC))/10 (degC))
}

DERIVATIVE states {
	settables(v)
	
    m' = (m_inf-m)/tau_m
    h' = (h_inf-h)/tau_h
}

UNITSOFF

PROCEDURE settables(v (mV)) {
	m_inf = (.0761*exp((v+94.22)/31.84)/(1+exp((v+1.17)/28.93)))^(.3333)
	tau_m = (.3632+1.158/(1+exp((v+55.96)/20.12)))/qt
	h_inf =1/(1+exp((v+53.3)/14.54))^4
	tau_h = (1.24+2.678/(1+exp((v+50)/16.027)))/qt

}

UNITSON

