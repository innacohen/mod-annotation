NEURON {
    POINT_PROCESS syn_nmda_std
    RANGE tau_o, tau_c, erev, i
    RANGE c1, c2, alpha, count
    NONSPECIFIC_CURRENT i
}

UNITS {
    (nA) = (nanoamp)
    (uA) = (microamp)
    (mA) = (milliamp)
    (A) = (amp)
    (mV) = (millivolt)
    (mS) = (millisiemens)
    (uS) = (microsiemens)
    (molar) = (1/liter)
    (kHz) = (kilohertz)
    (mM) = (millimolar)
    (um) = (micrometer)
    (S) = (siemens)
}

PARAMETER {
    tau_o = 5.0 (ms)
    tau_c = 80.0 (ms)
    erev = 0.0 (mV)
    c1 = 0.05
    c2 = -0.08
    syn_step = 1.25
    alpha = 1
}

ASSIGNED {
    v (mV)
    i (nA)
    factor
}

STATE {
    o
    c
}

INITIAL {
    o = 0
    c = 0
}

BREAKPOINT {
    SOLVE states METHOD cnexp
    i = mgBlock_std(v) * (c - o) * (v-erev)
}

NET_RECEIVE(weight (uS), w, count) {
    w=weight*pow(alpha,count)
    :printf("%g | %g \n", count, w)
    o = o + w*syn_step
    c = c + w*syn_step
    count=count+1
}


DERIVATIVE states {
    o' = -o/tau_o
    c' = -c/tau_c
}

UNITSOFF
FUNCTION mgBlock_std(v (mV)) {
    mgBlock_std = 1 / (1 + c1*exp(c2*v))
}
UNITSON
