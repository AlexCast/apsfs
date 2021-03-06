
#' PSF annular cumulative integral model
#'
#' Fits an exponential model to the radius cumulative integral of a PSF in 
#' annular geometry of a given scatter model, possibly with pressure dependency. 
#' 
#' @param psfm   A list of objects created by the function \code{mc_psf}.
#' @param press  Pressure in mbar or NULL. See details.
#' @param norm   Logical. Should the PSF be normalized to sum to unity?
#' @param nstart Number of random start positions for the multidimension 
#'               function optimization.
#'
#' @details
#' The function calculates the (normalized) cumulative integral of the annular 
#' PSF and fits the following model by optimization:
#'
#' F(r) = c1' - (c2' * e^(c3' * r) + c4' * e^(c5' * r) + c6' * e^(c7' * r)),
#' \describe{
#'   \item{c1' =}{ c1,}
#'   \item{c2' =}{ c2 / p,}
#'   \item{c3' =}{ c3 / p,}
#'   \item{c4' =}{ (c1' - c2') * c4,}
#'   \item{c5' =}{ c5,}
#'   \item{c6' =}{ (c1' - c2') * (1 - c4),}
#'   \item{c7' =}{ c6,}
#'   \item{p   =}{ press / 1013.25,}
#' }
#' and c1 to c6 are fitted parameters. Note that c1 = total diffuse transmittance
#' (or 1, if norm = TRUE) and that c2' + c4' + c6' = c1.
#'
#' If there is no pressure dependency (e.g., aerosol only), 'press' does not 
#' need to be specified. Internally, it will be set to 1013.25 mbar, p will 
#' equal unity and the pressure flag will be set to FALSE in the fit object 
#' metadata. The prediction function \code{predict_annular}, will track 
#' dependency on pressure and model domain.
#'
#' Note that adding multiple models in the input list will only be meaningfull 
#' if they are simulations for the same scatter at different surface pressure 
#' levels. If psfm is a list with more than one component and press is 
#' specified, norm is automatically set to TRUE.
#'
#' The cumulative annular integral PSF is as known as "environmental function".
#' The optimization is made with mean absolute relative error (MARE) as the 
#' error function.
#'
#' Note that 'PSF' in this package refers to the diffusely transmitted photons 
#' only. Photons from direct transmission are simulated and are part of the PSF,
#' but not included in the fit calculations.
#'
#' @return
#' A list with the following components: 
#' \describe{
#'   \item{type:}{Type of the fitted model;}
#'   \item{coefficients:}{Named vector with the 6 coefficients;}
#'   \item{mare:}{The minimum mean absolute relative error of the model fit;}
#'   \item{mare_seq:}{A sorted sequence of MARE of different random starts;}
#'   \item{convergence:}{Convergence code from \code{optim};}
#'   \item{press_dep:}{Logical flag indicating if there was pressure dependency;}
#'   \item{press_rng:}{The range of pressure values if fitted with pressure dependency.}
#' }
#'
#' @examples
#' # Fitting continental aerosol annular APSF simulation:
#'
#' data(asim)
#' psfl  <- asim["con"] # Note that input to function must be a list!
#' opt   <- fit_annular(psfl, norm = TRUE, nstart = 30)
#' opt
#' plot(opt$mare_seq, xlab = "Iteration", ylab = "MARE")
#'
#' # Fitting Rayleigh annular APSF simulation with pressure dependence:
#'
#' data(asim)
#' psfl  <- asim[["ray"]] # A list of Rayleigh simulations at different pressures 
#' opt   <- fit_annular(psfl, press = TRUE, norm = TRUE, nstart = 30)
#' opt
#' par(mfcol = c(1, 2))
#' plot(opt$mare_seq, xlab = "Iteration", ylab = "MARE")
#' plot(NA, xlim = c(0, 10), ylim = c(0, 1), xaxs = "i", yaxs = "i", 
#'   xlab = "Radius (km)", ylab = "Normalized f(r)")
#' x <- asim[["ray"]][[1]]$bin_brks
#' cols <- rev(rainbow(1:length(asim[["ray"]]), start = 0, end = 0.8))
#' for(i in 1:length(asim[["ray"]])) {
#'   points(x, cum_psf(asim[["ray"]][[i]], norm = TRUE), col = "grey")
#' }
#' for(i in 1:length(asim[["ray"]])) {
#'   press <- asim[["ray"]][[i]]$metadata$press
#'   lines(x, predict_annular(x, opt, type = "cumpsf", press = press))
#' }
#'
#' @export

fit_annular <- function(psfl, press = FALSE, norm = TRUE, nstart = 10) {

  if(length(psfl) > 1 & press) norm <- TRUE
  if(!press & length(psfl) > 1) {
    "psfl length > 1 but press set to FALSE. Only first psf will be used" %>%
    warning(call. = FALSE)
  }

  if(norm) {
    for(i in 1:length(psfl)) {
      psfl[[i]]$bin_phtw <- psfl[[i]]$bin_phtw / sum(psfl[[i]]$bin_phtw)
    }
  }

  if(press) {
    # Check that all simulations are at the same except for pressure:
    meta <- lapply(psfl, function(x) {x$metadata[c("res", "ext", "snsznt", "snsfov", "snspos")]})
    for(i in 2:length(meta)) {
      for(j in 1:4) {
        if(!identical(meta[[1]][[j]], meta[[i]][[j]])) {
          paste("All simulations included in a given fit with pressure dependence", 
            "must have the same parameters: res, ext, snsznt, snsfov, snspos") %>%
          stop(call. = FALSE)
        }
      }
    }

    n     <- length(psfl[[1]]$bin_mid)
    press <- sapply(psfl, function(x) { x$metadata$press }) %>%
             rep(each = n) %>%
             `/`(., 1013.25)
    pdep  <- TRUE
  } else {
    press <- 1
    pdep  <- FALSE
  }

  # Build function to be optimized:
  optfun <- function(x, ftot, r, finf, error = T, press) {
    xp1  <- x[1] * press^-1
    xp2  <- x[2] * press^-1
    est  <- finf - (xp1 * exp(xp2 * r) + (finf - xp1) * x[3] * exp(x[4] * r) + 
      (finf - xp1) * (1 - x[3]) * exp(x[5] * r))
    if(error) {
      return(mean(abs(est - ftot) / ftot, na.rm = TRUE))
    } else {
      return(est)
    }
  }

  # Fit model:
  # First poisition will always be zero and will be singular in the MARE 
  # calculation.
  vals <- numeric(nstart + 1)
  x    <- rep(psfl[[1]]$bin_brks[-1], length(psfl))
  y    <- NULL
  for(i in 1:length(psfl)) {
    y <- c(y, cum_psf(psfl[[i]])[-1])
  }
  st   <- c(0.05, -0.14, 0.23, -0.32, -0.05)
  opt  <- optim(st, optfun, method = "Nelder-Mead", ftot = y, r = x, 
    finf = max(y), control = list(maxit = 1E6), press = press)
  vals[1] <- opt$value

  for(i in 1:nstart) {
    st   <- runif(5, 0, 1) * c(1, -1, 1, -1, -1)
    optr <- optim(st, optfun, method = "Nelder-Mead", ftot = y, r = x, 
      finf = max(y), control = list(maxit = 1E6), press = press)
    vals[i + 1] <- optr$value
    if(optr$value < opt$value)
      opt <- optr
  }

  coef <- opt$par
  est  <- optfun(coef, r = x, finf = max(y), error = F, press = press)

  fit <- list(
    type = "annular",
    coefficients = c(
      c1 = max(y), 
      c2 = coef[1], 
      c3 = coef[2], 
      c4 = coef[3], 
      c5 = coef[4],
      c6 = coef[5]
    ),
    mare = opt$value,
    rmse = sqrt(mean((est - y)^2, na.rm = T)),
    mare_seq = sort(vals, decreasing = T),
    convergence = opt$convergence,
    press_dep = pdep,
    press_rng = range(press * 1013.25)
  )

  fit

}

#' Predict annular PSF fitted model
#'
#' Solves a fitted model from \code{fit_annular} for the PSF of the radial 
#' cummulative PSF at requested radius.
#'
#' @param r     The radial distances (km) at which the model should be evaluated.
#' @param fit   A model fit from \code{fit_annular} or \code{fit_sectorial}.
#' @param type  Type of prediction: 'psf', 'dpsf', or 'cumpsf'. See Details.
#' @param press Pressure in mbar or NULL. See details.
#' @param tpred Third predictor to be used when predicting a sectorial fit in 
#'              annular geomtry.
#'
#' @details If type = cumpsf, the model fit to the cumulative PSF will be 
#' evaluated at the desired radius points. If type = dpsf, the area derivative 
#' the PSF dPSF/dArea is returned. If type == psf, quadrature is used to on the 
#' average area derivative of the annulus and scaled by the area of the annulus. 
#' Note that in this case, r will be sorted and the returned values are for the 
#' mid points of the input vector of radius, so will have a length of 
#' length(r) - 1. Default is to return the PSF.
#'
#' @return A numeric vetor with the PSF, dPSF/dArea or cumulative PSF.
#'
#' @export

predict_annular <- function(r, fit, type = c("psf", "dpsf", "cpsf"), 
  press = NULL, tpred = NULL) {

  if(fit$type == "sectorial") {
    return(predict_sectorial(r, a = 2*pi, fit = fit, type = type, tpred = tpred))
  }

  if(is.null(press) & !fit$press_dep) {
    press <- 1013.25
  } else if(is.null(press) & fit$press_dep) {
    stop("'press' not specified for model fitted with pressure dependency", 
      call. = FALSE)
  }

  if(fit$press_dep) {
    if(any(press < fit$press_rng[1] | press > fit$press_rng[2]))
      paste0("Requested pressure beyond model domain of ", fit$press_rng[1], 
        " to ", fit$press_rng[2]) %>%
      warning(., call. = FALSE)
  }

  press <- press / 1013.25

  fun <- switch(type[1],
                "cpsf" = .pred_annular_cum,
                "dpsf" = .pred_annular_den,
                "psf"  = .pred_annular_psf,
                stop("type must be one of 'psf', 'dpsf', or 'cumpsf'", 
                  call. = FALSE)
         )

  if(type == "psf") r <- sort(r)
  fun(r = r, press = press, fit = fit)
}

.pred_annular_cum <- function(r, press, fit) {
  cf  <- fit$coefficients
  c1  <- cf[1]
  c2  <- cf[2] * press^-1
  c3  <- cf[3] * press^-1
  c4  <- (c1 - c2) * cf[4]
  c5  <- cf[5]
  c6  <- (c1 - c2) * (1 - cf[4])
  c7  <- cf[6]
  
  res <- c1 - (c2 * exp(c3 * r) + c4 * exp(c5 * r) + c6 * exp(c7 * r))

  res[is.na(res)] <- 0
  res
}

.pred_annular_den <- function(r, press, fit) {
  numDeriv::grad(.pred_annular_cum, x = r, press = press, fit = fit) / 2 / pi / r
}

.pred_annular_psf <- function(r, press, fit) {
  dpsf <- .pred_annular_den(r = r, press = press, fit = fit)
  psf  <- pi * diff(r^2) * (dpsf[-1] + dpsf[-length(dpsf)]) / 2
  if(r[1] == 0)
    psf[1] <- .pred_annular_cum(r = r[2], press = press, fit = fit)
  psf
}

