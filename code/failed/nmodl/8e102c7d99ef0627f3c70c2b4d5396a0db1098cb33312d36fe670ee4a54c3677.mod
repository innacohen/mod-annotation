NEURON {
    POINT_PROCESS syn_nmda_sat
    RANGE tau_o                           : parameter
    RANGE tau_c                          : parameter
    RANGE erev                              : parameter
    RANGE c1
    RANGE c2
    RANGE syn_step, nmda_sat, alpha, count
    RANGE gmax, vnull
    RANGE i                                 : exposure
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
    nmda_sat = 0.025 :0.03 : 0.01 is the original selected value
    gmax = 1.0
    vnull = 0.0
    alpha = 0.992
}

ASSIGNED {
    v (mV)
    i (nA)
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
    i = gmax*mgBlock(v) * (c - o) * (v-erev)
}

NET_RECEIVE(weight (uS), w, count) {
    w=weight*pow(alpha,count)
    :o = o + syn_step*weight
    :c = c + syn_step*weight
    o = o + syn_step*(1-(c-o)/nmda_sat)*w
    c = c + syn_step*(1-(c-o)/nmda_sat)*w
    :printf("%g \n", c-o)
    count=count+1
}


DERIVATIVE states {
    o' = -o/tau_o
    c' = -c/tau_c
}

UNITSOFF
FUNCTION mgBlock(v (mV)) {
    mgBlock = 1 / (1 + c1*exp(c2*(v-vnull)))
}
UNITSON
