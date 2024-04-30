#ifndef IMAGINE_UTIL_H
#define IMAGINE_UTIL_H


#include <stdbool.h>
#include <stdint.h>


// IMAGine API functions
int img_pushProgram(const IMAGine_Prog *prog);
int img_popVector(img_vecval_t * const buff, const int size);
int img_popVectorf(float * const buff, const int size, const int fracWidth);
int img_fxp2float(float * pfloat,
				  const img_vecval_t * pfxp,
				  const int size,
				  const int fracWidth);
void img_print_float(double val);


#endif  // IMAGINE_UTIL_H
