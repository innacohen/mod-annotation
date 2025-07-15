/* Created by Language version: 7.7.0 */
/* NOT VECTORIZED */
#define NRN_VECTORIZED 0
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "mech_api.h"
#undef PI
#define nil 0
#include "md1redef.h"
#include "section.h"
#include "nrniv_mf.h"
#include "md2redef.h"
 
#if METHOD3
extern int _method3;
#endif

#if !NRNGPU
#undef exp
#define exp hoc_Exp
extern double hoc_Exp(double);
#endif
 
#define nrn_init _nrn_init__kv72wt73wt
#define _nrn_initial _nrn_initial__kv72wt73wt
#define nrn_cur _nrn_cur__kv72wt73wt
#define _nrn_current _nrn_current__kv72wt73wt
#define nrn_jacob _nrn_jacob__kv72wt73wt
#define nrn_state _nrn_state__kv72wt73wt
#define _net_receive _net_receive__kv72wt73wt 
#define rate rate__kv72wt73wt 
#define state state__kv72wt73wt 
 
#define _threadargscomma_ /**/
#define _threadargsprotocomma_ /**/
#define _threadargs_ /**/
#define _threadargsproto_ /**/
 	/*SUPPRESS 761*/
	/*SUPPRESS 762*/
	/*SUPPRESS 763*/
	/*SUPPRESS 765*/
	 extern double *getarg();
 static double *_p; static Datum *_ppvar;
 
#define t nrn_threads->_t
#define dt nrn_threads->_dt
#define gbar _p[0]
#define gbar_columnindex 0
#define ik _p[1]
#define ik_columnindex 1
#define m _p[2]
#define m_columnindex 2
#define ek _p[3]
#define ek_columnindex 3
#define Dm _p[4]
#define Dm_columnindex 4
#define _g _p[5]
#define _g_columnindex 5
#define _ion_ek	*_ppvar[0]._pval
#define _ion_ik	*_ppvar[1]._pval
#define _ion_dikdv	*_ppvar[2]._pval
 
#if MAC
#if !defined(v)
#define v _mlhv
#endif
#if !defined(h)
#define h _mlhh
#endif
#endif
 
#if defined(__cplusplus)
extern "C" {
#endif
 static int hoc_nrnpointerindex =  -1;
 /* external NEURON variables */
 extern double celsius;
 /* declaration of user functions */
 static void _hoc_alpb(void);
 static void _hoc_alpa(void);
 static void _hoc_betb(void);
 static void _hoc_beta(void);
 static void _hoc_rate(void);
 static int _mechtype;
extern void _nrn_cacheloop_reg(int, int);
extern void hoc_register_prop_size(int, int, int);
extern void hoc_register_limits(int, HocParmLimits*);
extern void hoc_register_units(int, HocParmUnits*);
extern void nrn_promote(Prop*, int, int);
extern Memb_func* memb_func;
 
#define NMODL_TEXT 1
#if NMODL_TEXT
static const char* nmodl_file_text;
static const char* nmodl_filename;
extern void hoc_reg_nmodl_text(int, const char*);
extern void hoc_reg_nmodl_filename(int, const char*);
#endif

 extern void _nrn_setdata_reg(int, void(*)(Prop*));
 static void _setdata(Prop* _prop) {
 _p = _prop->param; _ppvar = _prop->dparam;
 }
 static void _hoc_setdata() {
 Prop *_prop, *hoc_getdata_range(int);
 _prop = hoc_getdata_range(_mechtype);
   _setdata(_prop);
 hoc_retpushx(1.);
}
 /* connect user functions to hoc names */
 static VoidFunc hoc_intfunc[] = {
 "setdata_kv72wt73wt", _hoc_setdata,
 "alpb_kv72wt73wt", _hoc_alpb,
 "alpa_kv72wt73wt", _hoc_alpa,
 "betb_kv72wt73wt", _hoc_betb,
 "beta_kv72wt73wt", _hoc_beta,
 "rate_kv72wt73wt", _hoc_rate,
 0, 0
};
#define alpb alpb_kv72wt73wt
#define alpa alpa_kv72wt73wt
#define betb betb_kv72wt73wt
#define beta beta_kv72wt73wt
 extern double alpb( double );
 extern double alpa( double );
 extern double betb( double );
 extern double beta( double );
 /* declare global and static user variables */
#define a0b a0b_kv72wt73wt
 double a0b = 0.0095;
#define a0a a0a_kv72wt73wt
 double a0a = 0.006;
#define b0b b0b_kv72wt73wt
 double b0b = 25;
#define b0 b0_kv72wt73wt
 double b0 = 75;
#define gmb gmb_kv72wt73wt
 double gmb = 0.85;
#define gmt gmt_kv72wt73wt
 double gmt = 0.96;
#define inf inf_kv72wt73wt
 double inf = 0;
#define kl kl_kv72wt73wt
 double kl = -11.65;
#define q10 q10_kv72wt73wt
 double q10 = 3.8;
#define taub taub_kv72wt73wt
 double taub = 0;
#define taua taua_kv72wt73wt
 double taua = 0;
#define tau tau_kv72wt73wt
 double tau = 0;
#define vhalfb vhalfb_kv72wt73wt
 double vhalfb = -60;
#define vhalft vhalft_kv72wt73wt
 double vhalft = -40;
#define vhalfl vhalfl_kv72wt73wt
 double vhalfl = -30.7;
#define zetab zetab_kv72wt73wt
 double zetab = 4;
#define zetat zetat_kv72wt73wt
 double zetat = 13;
 /* some parameters have upper and lower limits */
 static HocParmLimits _hoc_parm_limits[] = {
 0,0,0
};
 static HocParmUnits _hoc_parm_units[] = {
 "vhalfl_kv72wt73wt", "mV",
 "vhalft_kv72wt73wt", "mV",
 "a0a_kv72wt73wt", "/ms",
 "zetat_kv72wt73wt", "1",
 "gmt_kv72wt73wt", "1",
 "vhalfb_kv72wt73wt", "mV",
 "a0b_kv72wt73wt", "/ms",
 "zetab_kv72wt73wt", "1",
 "gmb_kv72wt73wt", "1",
 "gbar_kv72wt73wt", "mho/cm2",
 "ik_kv72wt73wt", "mA/cm2",
 0,0
};
 static double delta_t = 0.01;
 static double m0 = 0;
 static double v = 0;
 /* connect global user variables to hoc */
 static DoubScal hoc_scdoub[] = {
 "vhalfl_kv72wt73wt", &vhalfl_kv72wt73wt,
 "kl_kv72wt73wt", &kl_kv72wt73wt,
 "vhalft_kv72wt73wt", &vhalft_kv72wt73wt,
 "a0a_kv72wt73wt", &a0a_kv72wt73wt,
 "zetat_kv72wt73wt", &zetat_kv72wt73wt,
 "gmt_kv72wt73wt", &gmt_kv72wt73wt,
 "vhalfb_kv72wt73wt", &vhalfb_kv72wt73wt,
 "a0b_kv72wt73wt", &a0b_kv72wt73wt,
 "zetab_kv72wt73wt", &zetab_kv72wt73wt,
 "gmb_kv72wt73wt", &gmb_kv72wt73wt,
 "q10_kv72wt73wt", &q10_kv72wt73wt,
 "b0_kv72wt73wt", &b0_kv72wt73wt,
 "b0b_kv72wt73wt", &b0b_kv72wt73wt,
 "inf_kv72wt73wt", &inf_kv72wt73wt,
 "tau_kv72wt73wt", &tau_kv72wt73wt,
 "taua_kv72wt73wt", &taua_kv72wt73wt,
 "taub_kv72wt73wt", &taub_kv72wt73wt,
 0,0
};
 static DoubVec hoc_vdoub[] = {
 0,0,0
};
 static double _sav_indep;
 static void nrn_alloc(Prop*);
static void  nrn_init(NrnThread*, _Memb_list*, int);
static void nrn_state(NrnThread*, _Memb_list*, int);
 static void nrn_cur(NrnThread*, _Memb_list*, int);
static void  nrn_jacob(NrnThread*, _Memb_list*, int);
 
static int _ode_count(int);
static void _ode_map(int, double**, double**, double*, Datum*, double*, int);
static void _ode_spec(NrnThread*, _Memb_list*, int);
static void _ode_matsol(NrnThread*, _Memb_list*, int);
 
#define _cvode_ieq _ppvar[3]._i
 static void _ode_matsol_instance1(_threadargsproto_);
 /* connect range variables in _p that hoc is supposed to know about */
 static const char *_mechanism[] = {
 "7.7.0",
"kv72wt73wt",
 "gbar_kv72wt73wt",
 0,
 "ik_kv72wt73wt",
 0,
 "m_kv72wt73wt",
 0,
 0};
 static Symbol* _k_sym;
 
extern Prop* need_memb(Symbol*);

static void nrn_alloc(Prop* _prop) {
	Prop *prop_ion;
	double *_p; Datum *_ppvar;
 	_p = nrn_prop_data_alloc(_mechtype, 6, _prop);
 	/*initialize range parameters*/
 	gbar = 0.0001;
 	_prop->param = _p;
 	_prop->param_size = 6;
 	_ppvar = nrn_prop_datum_alloc(_mechtype, 4, _prop);
 	_prop->dparam = _ppvar;
 	/*connect ionic variables to this model*/
 prop_ion = need_memb(_k_sym);
 nrn_promote(prop_ion, 0, 1);
 	_ppvar[0]._pval = &prop_ion->param[0]; /* ek */
 	_ppvar[1]._pval = &prop_ion->param[3]; /* ik */
 	_ppvar[2]._pval = &prop_ion->param[4]; /* _ion_dikdv */
 
}
 static void _initlists();
  /* some states have an absolute tolerance */
 static Symbol** _atollist;
 static HocStateTolerance _hoc_state_tol[] = {
 0,0
};
 static void _update_ion_pointer(Datum*);
 extern Symbol* hoc_lookup(const char*);
extern void _nrn_thread_reg(int, int, void(*)(Datum*));
extern void _nrn_thread_table_reg(int, void(*)(double*, Datum*, Datum*, NrnThread*, int));
extern void hoc_register_tolerance(int, HocStateTolerance*, Symbol***);
extern void _cvode_abstol( Symbol**, double*, int);

 void _kv72wt73wt_reg() {
	int _vectorized = 0;
  _initlists();
 	ion_reg("k", -10000.);
 	_k_sym = hoc_lookup("k_ion");
 	register_mech(_mechanism, nrn_alloc,nrn_cur, nrn_jacob, nrn_state, nrn_init, hoc_nrnpointerindex, 0);
 _mechtype = nrn_get_mechtype(_mechanism[1]);
     _nrn_setdata_reg(_mechtype, _setdata);
     _nrn_thread_reg(_mechtype, 2, _update_ion_pointer);
 #if NMODL_TEXT
  hoc_reg_nmodl_text(_mechtype, nmodl_file_text);
  hoc_reg_nmodl_filename(_mechtype, nmodl_filename);
#endif
  hoc_register_prop_size(_mechtype, 6, 4);
  hoc_register_dparam_semantics(_mechtype, 0, "k_ion");
  hoc_register_dparam_semantics(_mechtype, 1, "k_ion");
  hoc_register_dparam_semantics(_mechtype, 2, "k_ion");
  hoc_register_dparam_semantics(_mechtype, 3, "cvodeieq");
 	hoc_register_cvode(_mechtype, _ode_count, _ode_map, _ode_spec, _ode_matsol);
 	hoc_register_tolerance(_mechtype, _hoc_state_tol, &_atollist);
 	hoc_register_var(hoc_scdoub, hoc_vdoub, hoc_intfunc);
 	ivoc_help("help ?1 kv72wt73wt /gpfs/gibbs/project/mcdougal/imc33/mod-extract/code/kv72wt73wt.mod\n");
 hoc_register_limits(_mechtype, _hoc_parm_limits);
 hoc_register_units(_mechtype, _hoc_parm_units);
 }
static int _reset;
static char *modelname = "CA1 KM channel from M. Taglialatela, Kv72wt+Kv73wt";

static int error;
static int _ninits = 0;
static int _match_recurse=1;
static void _modl_cleanup(){ _match_recurse=1;}
static int rate(double);
 
static int _ode_spec1(_threadargsproto_);
/*static int _ode_matsol1(_threadargsproto_);*/
 static int _slist1[1], _dlist1[1];
 static int state(_threadargsproto_);
 
double alpa (  double _lv ) {
   double _lalpa;
 _lalpa = exp ( 0.0378 * zetat * ( _lv - vhalft ) ) ;
   
return _lalpa;
 }
 
static void _hoc_alpa(void) {
  double _r;
   _r =  alpa (  *getarg(1) );
 hoc_retpushx(_r);
}
 
double alpb (  double _lv ) {
   double _lalpb;
 _lalpb = exp ( 0.0378 * zetab * ( _lv - vhalfb ) ) ;
   
return _lalpb;
 }
 
static void _hoc_alpb(void) {
  double _r;
   _r =  alpb (  *getarg(1) );
 hoc_retpushx(_r);
}
 
double beta (  double _lv ) {
   double _lbeta;
 _lbeta = exp ( 0.0378 * zetat * gmt * ( _lv - vhalft ) ) ;
   
return _lbeta;
 }
 
static void _hoc_beta(void) {
  double _r;
   _r =  beta (  *getarg(1) );
 hoc_retpushx(_r);
}
 
double betb (  double _lv ) {
   double _lbetb;
 _lbetb = exp ( 0.0378 * zetab * gmb * ( _lv - vhalfb ) ) ;
   
return _lbetb;
 }
 
static void _hoc_betb(void) {
  double _r;
   _r =  betb (  *getarg(1) );
 hoc_retpushx(_r);
}
 
/*CVODE*/
 static int _ode_spec1 () {_reset=0;
 {
   rate ( _threadargscomma_ v ) ;
   if ( m < inf ) {
     tau = taua ;
     }
   else {
     tau = taub ;
     }
   Dm = ( inf - m ) / tau ;
   }
 return _reset;
}
 static int _ode_matsol1 () {
 rate ( _threadargscomma_ v ) ;
 if ( m < inf ) {
   tau = taua ;
   }
 else {
   tau = taub ;
   }
 Dm = Dm  / (1. - dt*( ( ( ( - 1.0 ) ) ) / tau )) ;
  return 0;
}
 /*END CVODE*/
 static int state () {_reset=0;
 {
   rate ( _threadargscomma_ v ) ;
   if ( m < inf ) {
     tau = taua ;
     }
   else {
     tau = taub ;
     }
    m = m + (1. - exp(dt*(( ( ( - 1.0 ) ) ) / tau)))*(- ( ( ( inf ) ) / tau ) / ( ( ( ( - 1.0 ) ) ) / tau ) - m) ;
   }
  return 0;
}
 
static int  rate (  double _lv ) {
   double _la , _lqt , _lab , _lac ;
 _lqt = pow( q10 , ( ( celsius - 22.0 ) / 10.0 ) ) ;
   inf = ( 1.0 / ( 1.0 + exp ( ( _lv - vhalfl ) / kl ) ) ) ;
   _la = alpa ( _threadargscomma_ _lv ) ;
   _lab = alpb ( _threadargscomma_ _lv ) ;
   taua = ( b0 + beta ( _threadargscomma_ _lv ) / ( a0a * ( 1.0 + _la ) ) ) / _lqt ;
   taub = ( b0b + betb ( _threadargscomma_ _lv ) / ( a0b * ( 1.0 + _lab ) ) ) / _lqt ;
    return 0; }
 
static void _hoc_rate(void) {
  double _r;
   _r = 1.;
 rate (  *getarg(1) );
 hoc_retpushx(_r);
}
 
static int _ode_count(int _type){ return 1;}
 
static void _ode_spec(NrnThread* _nt, _Memb_list* _ml, int _type) {
   Datum* _thread;
   Node* _nd; double _v; int _iml, _cntml;
  _cntml = _ml->_nodecount;
  _thread = _ml->_thread;
  for (_iml = 0; _iml < _cntml; ++_iml) {
    _p = _ml->_data[_iml]; _ppvar = _ml->_pdata[_iml];
    _nd = _ml->_nodelist[_iml];
    v = NODEV(_nd);
  ek = _ion_ek;
     _ode_spec1 ();
  }}
 
static void _ode_map(int _ieq, double** _pv, double** _pvdot, double* _pp, Datum* _ppd, double* _atol, int _type) { 
 	int _i; _p = _pp; _ppvar = _ppd;
	_cvode_ieq = _ieq;
	for (_i=0; _i < 1; ++_i) {
		_pv[_i] = _pp + _slist1[_i];  _pvdot[_i] = _pp + _dlist1[_i];
		_cvode_abstol(_atollist, _atol, _i);
	}
 }
 
static void _ode_matsol_instance1(_threadargsproto_) {
 _ode_matsol1 ();
 }
 
static void _ode_matsol(NrnThread* _nt, _Memb_list* _ml, int _type) {
   Datum* _thread;
   Node* _nd; double _v; int _iml, _cntml;
  _cntml = _ml->_nodecount;
  _thread = _ml->_thread;
  for (_iml = 0; _iml < _cntml; ++_iml) {
    _p = _ml->_data[_iml]; _ppvar = _ml->_pdata[_iml];
    _nd = _ml->_nodelist[_iml];
    v = NODEV(_nd);
  ek = _ion_ek;
 _ode_matsol_instance1(_threadargs_);
 }}
 extern void nrn_update_ion_pointer(Symbol*, Datum*, int, int);
 static void _update_ion_pointer(Datum* _ppvar) {
   nrn_update_ion_pointer(_k_sym, _ppvar, 0, 0);
   nrn_update_ion_pointer(_k_sym, _ppvar, 1, 3);
   nrn_update_ion_pointer(_k_sym, _ppvar, 2, 4);
 }

static void initmodel() {
  int _i; double _save;_ninits++;
 _save = t;
 t = 0.0;
{
  m = m0;
 {
   rate ( _threadargscomma_ v ) ;
   m = inf ;
   }
  _sav_indep = t; t = _save;

}
}

static void nrn_init(NrnThread* _nt, _Memb_list* _ml, int _type){
Node *_nd; double _v; int* _ni; int _iml, _cntml;
#if CACHEVEC
    _ni = _ml->_nodeindices;
#endif
_cntml = _ml->_nodecount;
for (_iml = 0; _iml < _cntml; ++_iml) {
 _p = _ml->_data[_iml]; _ppvar = _ml->_pdata[_iml];
#if CACHEVEC
  if (use_cachevec) {
    _v = VEC_V(_ni[_iml]);
  }else
#endif
  {
    _nd = _ml->_nodelist[_iml];
    _v = NODEV(_nd);
  }
 v = _v;
  ek = _ion_ek;
 initmodel();
 }}

static double _nrn_current(double _v){double _current=0.;v=_v;{ {
   ik = gbar * m * ( v - ek ) ;
   }
 _current += ik;

} return _current;
}

static void nrn_cur(NrnThread* _nt, _Memb_list* _ml, int _type){
Node *_nd; int* _ni; double _rhs, _v; int _iml, _cntml;
#if CACHEVEC
    _ni = _ml->_nodeindices;
#endif
_cntml = _ml->_nodecount;
for (_iml = 0; _iml < _cntml; ++_iml) {
 _p = _ml->_data[_iml]; _ppvar = _ml->_pdata[_iml];
#if CACHEVEC
  if (use_cachevec) {
    _v = VEC_V(_ni[_iml]);
  }else
#endif
  {
    _nd = _ml->_nodelist[_iml];
    _v = NODEV(_nd);
  }
  ek = _ion_ek;
 _g = _nrn_current(_v + .001);
 	{ double _dik;
  _dik = ik;
 _rhs = _nrn_current(_v);
  _ion_dikdv += (_dik - ik)/.001 ;
 	}
 _g = (_g - _rhs)/.001;
  _ion_ik += ik ;
#if CACHEVEC
  if (use_cachevec) {
	VEC_RHS(_ni[_iml]) -= _rhs;
  }else
#endif
  {
	NODERHS(_nd) -= _rhs;
  }
 
}}

static void nrn_jacob(NrnThread* _nt, _Memb_list* _ml, int _type){
Node *_nd; int* _ni; int _iml, _cntml;
#if CACHEVEC
    _ni = _ml->_nodeindices;
#endif
_cntml = _ml->_nodecount;
for (_iml = 0; _iml < _cntml; ++_iml) {
 _p = _ml->_data[_iml];
#if CACHEVEC
  if (use_cachevec) {
	VEC_D(_ni[_iml]) += _g;
  }else
#endif
  {
     _nd = _ml->_nodelist[_iml];
	NODED(_nd) += _g;
  }
 
}}

static void nrn_state(NrnThread* _nt, _Memb_list* _ml, int _type){
Node *_nd; double _v = 0.0; int* _ni; int _iml, _cntml;
#if CACHEVEC
    _ni = _ml->_nodeindices;
#endif
_cntml = _ml->_nodecount;
for (_iml = 0; _iml < _cntml; ++_iml) {
 _p = _ml->_data[_iml]; _ppvar = _ml->_pdata[_iml];
 _nd = _ml->_nodelist[_iml];
#if CACHEVEC
  if (use_cachevec) {
    _v = VEC_V(_ni[_iml]);
  }else
#endif
  {
    _nd = _ml->_nodelist[_iml];
    _v = NODEV(_nd);
  }
 v=_v;
{
  ek = _ion_ek;
 { error =  state();
 if(error){fprintf(stderr,"at line 57 in file kv72wt73wt.mod:\n	SOLVE state METHOD cnexp\n"); nrn_complain(_p); abort_run(error);}
 } }}

}

static void terminal(){}

static void _initlists() {
 int _i; static int _first = 1;
  if (!_first) return;
 _slist1[0] = m_columnindex;  _dlist1[0] = Dm_columnindex;
_first = 0;
}

#if NMODL_TEXT
static const char* nmodl_filename = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/code/kv72wt73wt.mod";
static const char* nmodl_file_text = 
  "TITLE CA1 KM channel from M. Taglialatela, Kv72wt+Kv73wt\n"
  ": M. Migliore Jul 2012\n"
  "\n"
  "UNITS {\n"
  "	(mA) = (milliamp)\n"
  "	(mV) = (millivolt)\n"
  "\n"
  "}\n"
  "\n"
  "PARAMETER {\n"
  "	v 		(mV)\n"
  "	ek\n"
  "	celsius 	(degC)\n"
  "	gbar=.0001 	(mho/cm2)\n"
  "        vhalfl=-30.7   	(mV)\n"
  "	kl=-11.65\n"
  "        vhalft=-40   	(mV)\n"
  "        a0a=0.006      	(/ms)\n"
  "        zetat=13    	(1)\n"
  "        gmt=.96   	(1)\n"
  "        vhalfb=-60   	(mV)\n"
  "        a0b=0.0095      	(/ms)\n"
  "        zetab=4    	(1)\n"
  "        gmb=.85   	(1)\n"
  "	q10=3.8\n"
  "	b0=75\n"
  "	b0b=25\n"
  "	}\n"
  "\n"
  "\n"
  "NEURON {\n"
  "	SUFFIX kv72wt73wt\n"
  "	USEION k READ ek WRITE ik\n"
  "        RANGE  gbar,ik\n"
  "      GLOBAL inf, tau, taua, taub\n"
  "}\n"
  "\n"
  "STATE {\n"
  "        m\n"
  "}\n"
  "\n"
  "ASSIGNED {\n"
  "	ik (mA/cm2)\n"
  "        inf\n"
  "	tau\n"
  "    taua\n"
  "	taub\n"
  "}\n"
  "\n"
  "INITIAL {\n"
  "	rate(v)\n"
  "	m=inf\n"
  "}\n"
  "\n"
  "\n"
  "BREAKPOINT {\n"
  "	SOLVE state METHOD cnexp\n"
  "	ik = gbar*m*(v-ek)\n"
  "}\n"
  "\n"
  "\n"
  "FUNCTION alpa(v(mV)) {\n"
  "  alpa = exp(0.0378*zetat*(v-vhalft)) \n"
  "}\n"
  "\n"
  "FUNCTION alpb(v(mV)) {\n"
  "  alpb = exp(0.0378*zetab*(v-vhalfb)) \n"
  "}\n"
  "\n"
  "\n"
  "FUNCTION beta(v(mV)) {\n"
  "  beta = exp(0.0378*zetat*gmt*(v-vhalft)) \n"
  "}\n"
  "\n"
  "FUNCTION betb(v(mV)) {\n"
  "  betb = exp(0.0378*zetab*gmb*(v-vhalfb)) \n"
  "}\n"
  "\n"
  "\n"
  "DERIVATIVE state {\n"
  "    rate(v)\n"
  "    if (m<inf) {tau=taua} else {tau=taub}\n"
  "	m' = (inf - m)/tau\n"
  "}\n"
  "\n"
  "PROCEDURE rate(v (mV)) { :callable from hoc\n"
  "        LOCAL a,qt, ab, ac\n"
  "        qt=q10^((celsius-22)/10)\n"
  "        inf = (1/(1 + exp((v-vhalfl)/kl)))\n"
  "        a = alpa(v)\n"
  "        ab = alpb(v)\n"
  "        taua = (b0 + beta(v)/(a0a*(1+a)))/qt\n"
  "        taub = (b0b + betb(v)/(a0b*(1+ab)))/qt\n"
  "}\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  "\n"
  ;
#endif
