: Nicolas 17 avril 2012
TITLE AMPA16v8

INDEPENDENT {t FROM 0 TO 1 WITH 1 (ms)}

UNITS {
  (pA) = (picoamp)
  (mV) = (millivolt)
  (nS) = (nanosiemens)
}

NEURON {
  POINT_PROCESS AMPA16v8_noNC
  POINTER Glu
  RANGE LTP_ampaNbModFactor
  RANGE kass_re1   : association constant for reaction 1
  RANGE kdiss_re1  : dissociation constant for reaction 1
  RANGE kass_re5
  RANGE kdiss_re5
  RANGE kass_re11
  RANGE kdiss_re11
  RANGE kass_re12
  RANGE kdiss_re12
  RANGE kass_re16
  RANGE kdiss_re16
  RANGE kass_re19
  RANGE kdiss_re19
  RANGE conduc_O2
  RANGE conduc_O3
  RANGE conduc_O4
  RANGE Erev_AMPA
  RANGE sumOpen
  RANGE PNa
  RANGE PK
  RANGE PCa
  RANGE ICa_AMPA
  RANGE INa_AMPA
  RANGE IK_AMPA
  RANGE nbAMPAR
  RANGE NewNbAMPAR
  RANGE Deact_factor
  RANGE Desens_factor
  RANGE kdiss_re16_Init
  RANGE kass_re11_Init
  RANGE kass_re12_Init
  RANGE position_AMPAR
  NONSPECIFIC_CURRENT i
  RANGE g
  RANGE v1
}

PARAMETER {
  kass_re1 = 10.0     : k_1
  kdiss_re1 = 7.0     : k_-1
  kass_re5 = 10.0     : k_2
  kdiss_re5 = 0.00041 : k_-2
  kdiss_re11 = 0.001  : gamma_0
  kdiss_re12 = 0.017  : delta_1
  kass_re16 = 0.55    : beta
  kass_re19 = 0.2     : gamma_2
  kdiss_re19 = 0.035  : delta_2
  conduc_O2 = 9.0
  conduc_O3 = 15.0
  conduc_O4 = 21.0
  Erev_AMPA = 0.0
  PNa = 50.0
  PK = 49.5
  PCa = 0.5
  nbAMPAR = 80
  Deact_factor = 1.0
  Desens_factor = 1.0
  kdiss_re16_Init = 0.3    : alpha
  kass_re11_Init = 3.3e-06 : delta_0
  kass_re12_Init = 0.42    : gamma_1
  position_AMPAR = 60.0
  LTP_ampaNbModFactor = 1
  v
  Glu
  v1
}

STATE {
  R0
  R1
  R2
  R3
  R4
  D0
  D1
  D2
  D3
  D4
  E2
  E3
  E4
  O2
  O3
  O4
}

INITIAL {
  R0 = 1.0
  R1 = 0.0
  R2 = 0.0
  R3 = 0.0
  R4 = 0.0
  D0 = 0.0
  D1 = 0.0
  D2 = 0.0
  D3 = 0.0
  D4 = 0.0
  E2 = 0.0
  E3 = 0.0
  E4 = 0.0
  O2 = 0.0
  O3 = 0.0
  O4 = 0.0
}
ASSIGNED{
  kdiss_re16
  kass_re11
  kass_re12
  NewNbAMPAR
  sumOpen
  i
  INa_AMPA
  IK_AMPA
  ICa_AMPA
  g

}


BREAKPOINT {
  SOLVE states METHOD derivimplicit

  kdiss_re16 = kdiss_re16_Init / Deact_factor
  kass_re11 = kass_re11_Init / Desens_factor
  kass_re12 = kass_re12_Init / Desens_factor

  : NewNbAMPAR = nbAMPAR * LTP_ampaNbModFactor


  NewNbAMPAR = nbAMPAR * (16/40) : scale physiologically

  sumOpen = O2 + O3 + O4
  g= (conduc_O2 * O2 + conduc_O3 * O3 + conduc_O4 * O4) * NewNbAMPAR * 1e-3 : pS -> nS
  i= (conduc_O2 * O2 + conduc_O3 * O3 + conduc_O4 * O4) * (v- Erev_AMPA) * NewNbAMPAR * 1e-3 : pA

  INa_AMPA = PNa / 100 * i
  IK_AMPA = PK / 100 * i
  ICa_AMPA = PCa / 100 * i

  v1 = v
}

DERIVATIVE states {
  LOCAL dummy ,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,pa,pb,pc,pd,pe,pf,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p1a,p1b,p1c,p1d,p1e,p1f,p20
  p1 = kass_re1
  p2 = kdiss_re1
  p3 = kass_re5
  p4 = kdiss_re5
  p5 = kass_re11
  p6 = kdiss_re11
  p7 = kass_re12
  p8 = kdiss_re12
  p9 = kass_re16
  pa = kdiss_re16
  pb = kass_re19
  pc = kdiss_re19
  pd = conduc_O2
  pe = conduc_O3
  pf = conduc_O4
  p10 = Erev_AMPA
: p11 = current_AMPA
: p12 = sumOpen
  p13 = PNa
  p14 = PK
  p15 = PCa
  p16 = ICa_AMPA
  p17 = INa_AMPA
  p18 = IK_AMPA
  p19 = nbAMPAR
  p1a = NewNbAMPAR
  p1b = Deact_factor
  p1c = Desens_factor
  p1d = kdiss_re16_Init
  p1e = kass_re11_Init
  p1f = kass_re12_Init
  p20 = position_AMPAR

  : Reaction re1 (R0, Glu) -> (R1) with formula : 4*p1*R0*Glu - 1*p2*R1 (ORIGINALLY: 4 * kass_re1 * R0 * Glu - 1 * kdiss_re1 * R1)
  : Reaction re2 (R1, Glu) -> (R2) with formula : 3*p1*R1*Glu - 2*p2*R2 (ORIGINALLY: 3 * kass_re1 * R1 * Glu - 2 * kdiss_re1 * R2)
  : Reaction re3 (R2, Glu) -> (R3) with formula : 2*p1*R2*Glu - 3*p2*R3 (ORIGINALLY: 2 * kass_re1 * R2 * Glu - 3 * kdiss_re1 * R3)
  : Reaction re4 (R3, Glu) -> (R4) with formula : 1*p1*R3*Glu - 4*p2*R4 (ORIGINALLY: 1 * kass_re1 * R3 * Glu - 4 * kdiss_re1 * R4)
  : Reaction re5 (D0, Glu) -> (D1) with formula : 3*p3*D0*Glu - p4*D1 (ORIGINALLY: 3 * kass_re5 * D0 * Glu - kdiss_re5 * D1)
  : Reaction re6 (D1, Glu) -> (D2) with formula : 3*p1*D1*Glu - p2*D2 (ORIGINALLY: 3 * kass_re1 * D1 * Glu - kdiss_re1 * D2)
  : Reaction re7 (D2, Glu) -> (D3) with formula : 2*p1*D2*Glu - 2*p2*D3 (ORIGINALLY: 2 * kass_re1 * D2 * Glu - 2 * kdiss_re1 * D3)
  : Reaction re8 (D3, Glu) -> (D4) with formula : 1*p1*D3*Glu - 3*p2*D4 (ORIGINALLY: 1 * kass_re1 * D3 * Glu - 3 * kdiss_re1 * D4)
  : Reaction re9 (E2, Glu) -> (E3) with formula : 2*p1*E2*Glu - p2*E3 (ORIGINALLY: 2 * kass_re1 * E2 * Glu - kdiss_re1 * E3)
  : Reaction re10 (E3, Glu) -> (E4) with formula : p1*E3*Glu - 2*p2*E4 (ORIGINALLY: kass_re1 * E3 * Glu - 2 * kdiss_re1 * E4)
  : Reaction re11 (R0) -> (D0) with formula : 4*p5*R0 - p6*D0 (ORIGINALLY: 4 * kass_re11 * R0 - kdiss_re11 * D0)
  : Reaction re12 (R1) -> (D1) with formula : 1*p1f*R1 - p8*D1 (ORIGINALLY: 1 * kass_re12_Init * R1 - kdiss_re12 * D1)
  : Reaction re13 (R2) -> (D2) with formula : 2*p1f*R2 - p8*D2 (ORIGINALLY: 2 * kass_re12_Init * R2 - kdiss_re12 * D2)
  : Reaction re14 (R3) -> (D3) with formula : 3*p1f*R3 - p8*D3 (ORIGINALLY: 3 * kass_re12_Init * R3 - kdiss_re12 * D3)
  : Reaction re15 (R4) -> (D4) with formula : 4*p1f*R4 - p8*D4 (ORIGINALLY: 4 * kass_re12_Init * R4 - kdiss_re12 * D4)
  : Reaction re16 (R2) -> (O2) with formula : 2*p9*R2 - pa*O2 (ORIGINALLY: 2 * kass_re16 * R2 - kdiss_re16 * O2)
  : Reaction re17 (R3) -> (O3) with formula : 3*p9*R3 - pa*O3 (ORIGINALLY: 3 * kass_re16 * R3 - kdiss_re16 * O3)
  : Reaction re18 (R4) -> (O4) with formula : 4*p9*R4 - pa*O4 (ORIGINALLY: 4 * kass_re16 * R4 - kdiss_re16 * O4)
  : Reaction re19 (D2) -> (E2) with formula : 1*pb*D2 - pc*E2 (ORIGINALLY: 1 * kass_re19 * D2 - kdiss_re19 * E2)
  : Reaction re20 (D3) -> (E3) with formula : 2*pb*D3 - pc*E3 (ORIGINALLY: 2 * kass_re19 * D3 - kdiss_re19 * E3)
  : Reaction re21 (D4) -> (E4) with formula : 3*pb*D4 - pc*E4 (ORIGINALLY: 3 * kass_re19 * D4 - kdiss_re19 * E4)
  R0' =  - (4*p1*R0*Glu - 1*p2*R1) - (4*p5*R0 - p6*D0) 
  R1' =  (4*p1*R0*Glu - 1*p2*R1) - (3*p1*R1*Glu - 2*p2*R2) - (1*p1f*R1 - p8*D1) 
  R2' =  (3*p1*R1*Glu - 2*p2*R2) - (2*p1*R2*Glu - 3*p2*R3) - (2*p1f*R2 - p8*D2) - (2*p9*R2 - pa*O2) 
  R3' =  (2*p1*R2*Glu - 3*p2*R3) - (1*p1*R3*Glu - 4*p2*R4) - (3*p1f*R3 - p8*D3) - (3*p9*R3 - pa*O3) 
  R4' =  (1*p1*R3*Glu - 4*p2*R4) - (4*p1f*R4 - p8*D4) - (4*p9*R4 - pa*O4) 
  D0' =  - (3*p3*D0*Glu - p4*D1) + (4*p5*R0 - p6*D0) 
  D1' =  (3*p3*D0*Glu - p4*D1) - (3*p1*D1*Glu - p2*D2) + (1*p1f*R1 - p8*D1) 
  D2' =  (3*p1*D1*Glu - p2*D2) - (2*p1*D2*Glu - 2*p2*D3) + (2*p1f*R2 - p8*D2) - (1*pb*D2 - pc*E2) 
  D3' =  (2*p1*D2*Glu - 2*p2*D3) - (1*p1*D3*Glu - 3*p2*D4) + (3*p1f*R3 - p8*D3) - (2*pb*D3 - pc*E3) 
  D4' =  (1*p1*D3*Glu - 3*p2*D4) + (4*p1f*R4 - p8*D4) - (3*pb*D4 - pc*E4) 
  E2' =  - (2*p1*E2*Glu - p2*E3) + (1*pb*D2 - pc*E2) 
  E3' =  (2*p1*E2*Glu - p2*E3) - (p1*E3*Glu - 2*p2*E4) + (2*pb*D3 - pc*E3) 
  E4' =  (p1*E3*Glu - 2*p2*E4) + (3*pb*D4 - pc*E4) 
  O2' =  (2*p9*R2 - pa*O2) 
  O3' =  (3*p9*R3 - pa*O3) 
  O4' =  (4*p9*R4 - pa*O4) 
}

