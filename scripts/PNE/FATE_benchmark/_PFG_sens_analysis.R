##' ---------------------------------------------------------------------------
##' title: Design a factorial experience plan for FATEHD
##' date: 03/03/2016
##' author: Damien G.
##' ---------------------------------------------------------------------------

##' ## Problem description
##' 
##' We want to see what is the influence of successional parameters within
##' FATEHD simulation ability to reproduce PNE vegetation. We will focus
##' on 3 subarea of the PNE and investigate 3 groups of parameters (3 factors tested
##' by parmaeters) for our 3 type of plants (C, 2xH, 2xP).. That implies ~500000 combinations
##' we will first investigate ~20000 combinations
##' 

library(dplyr)

params.succ <- c("TAS", "LIGHT", "DIST")
params.grp <- c("C", "HA", "HB", "PA", "PB")
params.level <- c("REF", "TEST")

params.succ.grp.df <- expand.grid(params.grp = params.grp, params.succ = params.succ) %>%
  mutate(id = paste(params.succ, params.grp, sep = "."))

params <- params.succ.grp.df$id
fact.simpl <- 3

set.seed(123)
library(FrF2)

# fact.dat <- FrF2(resolution = 4,
#                  nfactors = 96,
#                  # factor.names = params,
#                  default.levels = c("REF", "TEST"))

fact.dat <- FrF2(nruns = length(params.level)^(length(params) - fact.simpl),
                 nfactors = length(params),
                 factor.names = params,
                 default.levels = c("REF", "TEST"))

# library(planor)
# fact.obj <- planor.factors(factors = params, nlevels = 2)
# 
# fact.key <- planor.designkey(factors = fact.obj,
#                              resolution = 4,
#                              nunits = length(params.level)^(length(params) - fact.simpl))
# 
# fact.plan <- planor.design(fact.key)
# sum(duplicated(fact.plan@design))
# dim(fact.plan@design)
# fact.plan@nunits
# fact.dat <- data.frame(simul.id = 1:nrow(fact.plan@design), fact.plan@design)

fact.dat$simul.id <- 1:nrow(fact.dat)
head(fact.dat)
write.csv(fact.dat, file = "~/Work/FATEHD/benchmarking/fatehd_params_test/grid/pfg_params_test/fhdpfgpt/Data/fact.data.csv", row.names = FALSE)


##' ## Define the rules to define new set of parameters 

dat <- read.csv("~/Work/FATEHD/benchmarking/workdir/FATE_6STRATA_TEST_PFG/editParamsC24_newH8.csv", sep = ";", stringsAsFactors = FALSE)
pfg.names <- dat$group
pfg.group <- rep(NA, length(pfg.names))
names(pfg.group) <- pfg.names

pfg.group[grepl("^C" , names(pfg.group))] <- "C"
pfg.group[grepl("^H[1,2,3,5,6,9,10]" , names(pfg.group))] <- "HA"
pfg.group[grepl("^H[4,7,8]" , names(pfg.group))] <- "HB"
pfg.group[grepl("^P[1,4,5]" , names(pfg.group))] <- "PA"
pfg.group[grepl("^P[2,3,6,7,8]" , names(pfg.group))] <- "PB"

params.names <- params

save(pfg.names, pfg.group, params.names, file = "~/Work/FATEHD/benchmarking/workdir/pfg_benchmark_obj.RData")
