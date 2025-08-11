TITLE Slow Ca-dependent potassium current
                            :
                            :   Ca++ dependent K+ current IC responsible for slow AHP
                            :   Differential equations
                            :
                            :   Model based on a first order kinetic scheme
                            :
                            :       + n cai <->     (alpha,beta)
                            :
                            :   Following this model, the activation fct will be half-activated at 
                            :   a concentration of Cai = (beta/alpha)^(1/n) = cac (parameter)
                            :
                            :   The mod file is here written for the case n=2 (2 binding sites)
                            :   ---------------------------------------------
                            :
                            :   This current models the "slow" IK[Ca] (IAHP): 
                            :      - potassium current
                            :      - activated by intracellular calcium
                            :      - NOT voltage dependent
                            :
                            :   A minimal value for the time constant has been added
                            :
                            :   Ref: Destexhe et al., J. Neurophysiology 72: 803-818, 1994.
                            :   See also: http://www.cnl.salk.edu/~alain , http://cns.fmed.ulaval.ca
                            :   modifications by Yiota Poirazi 2001 (poirazi@LNC.usc.edu)
			    :   taumin = 0.5 ms instead of 0.1 ms	

                            NEURON {
                                    SUFFIX kca
									POINTER stim_i
                                    USEION k READ ek WRITE ik
                                    USEION ca READ cai
                                    RANGE flag, curr, gk, gbar, m_inf, tau_m,ik,ek2,vrun,count,vvrun,taun2,vrun2,delta2, stim_moltK
                                    GLOBAL  beta, cac,alpha
                            }


                            UNITS {
                                    (mA) = (milliamp)
                                    (mV) = (millivolt)
                                    (molar) = (1/liter)
                                    (mM) = (millimolar)
                            }


                            PARAMETER { 
							      curr
								  
                                    v               (mV)
                                    celsius = 36    (degC)
                                    ek      = -80   (mV)
									 ek2      = -80   (mV)
                                    cai     = 2.4e-5 (mM)           : initial [Ca]i
                                    gbar    = 0.01   (mho/cm2)
                                    beta    = 0.03 :0.03   (1/ms)          : backward rate constant
                                    cac     = 0.035  (mM)            : middle point of activation fct
       				               taumin  = 0.5    (ms)            : minimal value of the time cst
                                    gk
									count=1
									vrun (mV)
									delta=0
									vinit=-76.2
									alpha=1.06
									 timestep=1000
									vrun2
									v0
									dv0
									ddv
									flag=0
									FK = 2
									PK = 1
									BK = 2.11
									CK = 48
									stim_moltK=1
																		
                                  }


                            STATE {m}        : activation variable to be solved in the DEs       

                            ASSIGNED {       : parameters needed to solve DE 
                                    ik      (mA/cm2)
                                    m_inf
                                    tau_m   (ms)
                                    tadj
									vvrun
									taun2
									stim_i
                            }
                            BREAKPOINT { 
                                    SOLVE states METHOD cnexp:derivimplicit
                                    gk = gbar*m*m*m     : maximum channel conductance
									ek2=ek+vvrun*alpha
									ik = gk*(v - ek2)    : potassium current induced by this channel
                            }

                            DERIVATIVE states { 
                                    evaluate_fct(v,cai)
                                    m' = (m_inf - m) / tau_m
                            }

                            UNITSOFF
                            INITIAL {
                            :
                            :  activation kinetics are assumed to be at 22 deg. C
                            :  Q10 is assumed to be 3
                            :
							        vrun=0
									vvrun=vrun
                                    tadj = 3 ^ ((celsius-22.0)/10) : temperature-dependent adjastment factor
                                    evaluate_fct(v,cai)
                                    m = m_inf
                            }
		
		BEFORE STEP { LOCAL i
       	
		  if(stim_i==0 && flag==0){ 
		  vrun=0
		  vvrun=0
		  
	    }else{
		 flag=1
		             		  
		delta=v-vinit
		if (count<timestep+1){
		   vrun= (delta-vrun)*(FK/(count+1))+vrun
	       vrun2=vrun 
		 }else{

		vrun2= (delta)*(FK/(timestep+1))+vrun2*pow((1-FK/(timestep+1)),PK)
			
			}
		
	   vvrun=(BK*vrun2/(1+vrun2/CK))
	    
		count=count+1   
        }						
		 :sh2=sh+alphash1*vvrun
	
}
   
   
                            PROCEDURE evaluate_fct(v(mV),cai(mM)) {  LOCAL car,i
                                    car = (cai/cac)^4
                                    m_inf = car / ( 1 + car )      : activation steady state value
                                    tau_m =  1 / beta / (1 + car) / tadj
                                    if(tau_m < taumin) { tau_m = taumin }   : activation min value of time cst
									   
									    
		
				
									
									
								}
                            UNITSON
