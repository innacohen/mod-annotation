#include <stdio.h>
#include "hocdec.h"
extern int nrnmpi_myid;
extern int nrn_nobanner_;
#if defined(__cplusplus)
extern "C" {
#endif

extern void _cal2_reg(void);
extern void _ka_reg(void);
extern void _kaprox_reg(void);
extern void _kv72wt73wt_reg(void);
extern void _NaP_reg(void);

void modl_reg() {
  if (!nrn_nobanner_) if (nrnmpi_myid < 1) {
    fprintf(stderr, "Additional mechanisms from files\n");
    fprintf(stderr, " \"cal2.mod\"");
    fprintf(stderr, " \"ka.mod\"");
    fprintf(stderr, " \"kaprox.mod\"");
    fprintf(stderr, " \"kv72wt73wt.mod\"");
    fprintf(stderr, " \"NaP.mod\"");
    fprintf(stderr, "\n");
  }
  _cal2_reg();
  _ka_reg();
  _kaprox_reg();
  _kv72wt73wt_reg();
  _NaP_reg();
}

#if defined(__cplusplus)
}
#endif
