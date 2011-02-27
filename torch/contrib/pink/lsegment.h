/*
Copyright ESIEE (2009) 

m.couprie@esiee.fr

This software is an image processing library whose purpose is to be
used primarily for research and teaching.

This software is governed by the CeCILL  license under French law and
abiding by the rules of distribution of free software. You can  use, 
modify and/ or redistribute the software under the terms of the CeCILL
license as circulated by CEA, CNRS and INRIA at the following URL
"http://www.cecill.info". 

As a counterpart to the access to the source code and  rights to copy,
modify and redistribute granted by the license, users are provided only
with a limited warranty  and the software's author,  the holder of the
economic rights,  and the successive licensors  have only  limited
liability. 

In this respect, the user's attention is drawn to the risks associated
with loading,  using,  modifying and/or developing or reproducing the
software by the user in light of its specific status of free software,
that may mean  that it is complicated to manipulate,  and  that  also
therefore means  that it is reserved for developers  and  experienced
professionals having in-depth computer knowledge. Users are therefore
encouraged to load and test the software's suitability as regards their
requirements in conditions enabling the security of their systems and/or 
data to be ensured and,  more generally, to use and operate it in the 
same conditions as regards security. 

The fact that you are presently reading this means that you have had
knowledge of the CeCILL license and that you accept its terms.
*/
#ifdef __cplusplus
extern "C" {
#endif
#undef SURFACE
#undef PROFONDEUR
#undef VOLUME
#define SURFACE      1
#define PROFONDEUR   2
#define VOLUME       4
#ifdef VERSION_EXPERIMENTALE
#define PERIMETRE    8
#define CIRCULARITE  16
#define ROOTDIST     32
#define NBTROUS      64
#define DENSTROUS    128
#define EXCENTRICITE 256
#endif
/* ============== */
/* prototype for lsegment.c */
/* ============== */

extern int32_t lsegment(
             struct xvimage *image,
             int32_t connex,
             int32_t mesure, 
             int32_t seuilsurf,
             int32_t seuilprof,
             int32_t seuilvol,
#ifdef VERSION_EXPERIMENTALE
             int32_t seuilperim,
             int32_t seuilcirc,
             int32_t seuilrdist,
             int32_t seuiltrou,
             int32_t seuildtrou,
             int32_t seuilexcen,
#endif
             int32_t maximise
);

#ifdef __cplusplus
}
#endif