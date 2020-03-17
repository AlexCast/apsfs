[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
 
# apsfs

### Atmospheric Point Spread Function simulation

This R package contains functions to calculate the atmopsheric point spread function (PSF) for a given view angle and atmospheric composition and profile. It also provide functions to fit the simulations to uni or bidimensional models and to reconstruct the APSFs in grid based on those fitted models.

The PSF is calculated with backward Monte Carlo with the following simplifications:
* Plane paralel geometry;
* Layered medium;
* Lambertian surface;
* Scalar elastic scattering.

Polarization, inelastic scattering and atmospheric turbulence are not included. Molecular absorption can be included, but vertical profile of absorption must be supplied by the user.

Simulations can be recorded in an annular geometry (unidimensional) for symmetric conditions (flat Lambertian surfaces and sensor looking at nadir). For asymmetric conditions (surface elevation, non-Lambertian BRDF and/or zenith view angles away from nadir) the sectorial (radius, azimuth) and grid (x, y) geometries are available.

The results can then be fitted to models to provide flexibility for application. Cumulative annular data is fitted to a three term exponential function and can include pressure dependence. Cumulative sectorial data is fitted with Singular Value Decomposition and can include third predictor (e.g., view angle dependence). Grid data can be fitted with Zernike polynomials (needs further development!). Those models can be solved to retrive the cumulative APSF, the area integral APSF or the (density) PSF (1/m<sup>2</sup>).

A C compiler is necessary to access the C version of the Monte Carlo code. A (much slower) R version of the same code is also provided if a C compiler is not available.

A [**User Guide**](https://github.com/AlexCast/apsfs/wiki) is available as a GitHub wiki.

```
This package was written for personal use. It is well documented and is sufficiently 
generic that might be of use to others. It is provided as is, without warranties. 
Please note follow the licence terms in using, modifiying and sharing this code.
```

### Install from Github:

The package depends on packages magrittr and numDeriv.

```
# install.packages(c("remotes", "magrittr", "numDeriv"))
remotes::install_github("AlexCast/apsfs")
```

