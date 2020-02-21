[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip) 
# apsfs

### Atmospheric Point Spread Function simulation

This R package contains functions to calculate the atmopsheric point spread function (PSF) for a given geometry and atmospheric composition and profile, and functions to fit this data to annular or grid models.

The PSF is calculated with backward Monte Carlo with the following simplifications:
* Plane paralel geometry;
* Layered medium;
* Lambertian surface;
* Inelastic scattering not included;
* Atmospheric turbulence not included;
* Molecular absorption included but must be supplied externally.

Simulations can be recorded in a annular geometry for symmetric conditions (Lambertian surfaces and sensor looking at nadir) or grid geometry for asymmetric conditions (surface BRDF and/or zenith view angles away from nadir).

The results can then be fitted to models to provide flexibility for application. Cumulative annular data is fitted to a two term exponential function, while grid data is fitted with modified Zernike polynomials.

A C compiler is necessary to access the C version of the Monte Carlo code. A (much slower) R version of the code is also provided.

```
This package was written for personal use. It is well documented and is sufficiently 
generic that might be of use to others. It is provided as is, without warranties.
```

### Install from Github:

The package depends on packages magrittr and numDeriv and on the unpublished package rho.

```
# install.packages(c("remotes", "magrittr", "numDeriv"))
# remotes::install_github("AlexCast/rho")
remotes::install_github("AlexCast/apsfs")
```

