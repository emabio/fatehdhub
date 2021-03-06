## reevaluate fatehd outputs
library(gridExtra)
library(raster)
library(dplyr)
library(tidyr)
library(ggplot2)
library(rasterVis)


setwd("/nfs_scratch2/dgeorges/FATE_newHS/workdir/")
rm(list = ls())

for(simul.id in c(4)){
  # simul.id <- 3
  
  simul.desc <- switch(simul.id,
                      '1' = "formal HS",
                      '2' = "HS bin",
                      '3' = "HS scaled optim TSS at 0.75",
                      '4' = "HS scaled 95% sens at 0.5")
  
  path_input_data <- "/nfs_scratch2/dgeorges/FATE_newHS/data/"
  path_input_sdm <- "/nfs_scratch2/dgeorges/FATE_newHS/SIMUL_6STRATA/DATA/PFGS/ENVSUIT/_FORMAL_HS/"
  path_input_fate <- "/nfs_scratch2/dgeorges/FATE_newHS/SIMUL_6STRATA/outputsTables/"
  path_to_mask <- "/nfs_scratch2/dgeorges/FATE_newHS/SIMUL_6STRATA/DATA/MASK/maskEcrins.asc"
  
  path_output <- "/nfs_scratch2/dgeorges/FATE_newHS/workdir/effect_of_hs_on_fatehd"
  dir.create(path_output, showWarnings = FALSE, recursive = TRUE)
  
  projETRS89 <- "+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 +ellps=GRS80 +units=m +no_defs"
  projLCC <- "+proj=lcc +lat_1=45.89891888888889 +lat_2=47.69601444444444 +lat_0=46.8 +lon_0=2.337229166666667 +x_0=600000 +y_0=2200000 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
  
  
  listeGrp <- get(load(file.path(path_input_data, "determinantes")))
  pfg.list <- names(listeGrp) 
  
  poly.ecrins <- shapefile(file.path(path_input_data,"mask_ecrins","maskecrins.shp"))
  poly.ecrins <- spTransform(poly.ecrins, CRS(projETRS89))
  
  
  
  ## laod PFGS observations over the ecrins
  occ.obj.list <- vector(mode = "list", length = length(pfg.list))
  names(occ.obj.list) <- pfg.list
  
  cat("\n> getting pfg occurences..")
  for(pfg_ in pfg.list){
    cat("\t", pfg_)
    (load(file.path(path_input_data, paste0("data.", pfg_, ".aust.newSetOfVar.austExt.RData"))))
    pts.in.ecrins <- pft.xyETRS89 %over% poly.ecrins
    pts.in.ecrins <- !is.na(pts.in.ecrins$GRIDCODE)
    occ.obj.list[[pfg_]] <- SpatialPointsDataFrame(pft.xyETRS89[pts.in.ecrins], data.frame(pft.occ = pft.occ[pts.in.ecrins]))
  }
  
  ## Load PFGS SMD's observation
  sdm.ras.list <- sdm.obj.list <- vector(mode = "list", length = length(pfg.list))
  names(sdm.ras.list) <- names(sdm.obj.list) <- pfg.list
  
  cat("\n> getting pfg habitat suitability..")
  for(pfg_ in pfg.list){
    cat("\t", pfg_)
    sdm.ras.list[[pfg_]] <- raster(file.path(path_input_sdm, paste0("HS_f0_", pfg_,".asc")), crs = CRS(projETRS89))
    sdm.obj.list[[pfg_]] <- raster::extract(sdm.ras.list[[pfg_]], occ.obj.list[[pfg_]], sp = TRUE)
  }
  
  ## Load PFGS FATE Light ref
  maskSimul = raster(path_to_mask, crs = CRS(projETRS89))
  
  sim.light.ras.list <- sim.light.obj.list <- vector(mode = "list", length = length(pfg.list))
  names(sim.light.ras.list) <- names(sim.light.obj.list) <- pfg.list
  
  (load(file.path(path_input_fate, paste0("arrayPFG_year850_rep", simul.id))))
  
  for(pfg_ in pfg.list){
    sim.light.ras.list[[pfg_]] <- maskSimul
    sim.light.ras.list[[pfg_]][] <- arrayPFG[, grep(paste0(pfg_,"_"), colnames(arrayPFG))]
    sim.light.obj.list[[pfg_]] <- raster::extract(sim.light.ras.list[[pfg_]], occ.obj.list[[pfg_]], sp = TRUE)
  }
  
  ## calculate the TSS of each simul
  for(pfg_ in pfg.list){
    cat("\n>", pfg_)
    hs.stk <- raster::stack(sim.light.ras.list[[pfg_]] / cellStats(sim.light.ras.list[[pfg_]], max),
                            sdm.ras.list[[pfg_]])
    hs.stk <- mask(hs.stk, maskSimul)
    names(hs.stk) <- c("fatehd", "sdm")
    
    pred.ecrins <- data.frame(occ = occ.obj.list[[pfg_]]@data[,1], 
                              sdm = sdm.obj.list[[pfg_]]@data[,2],
                              fatehd = sim.light.obj.list[[pfg_]]@data[,2])
    pred.ecrins <- na.omit(pred.ecrins)
    
    pred.ecrins$fatehd <- pred.ecrins$fatehd / max(pred.ecrins$fatehd)
    
    cat("\n\tevaluating models")
    eval.test.df <- NULL
    for(mod.name in colnames(pred.ecrins)[-1]){
      eval.test.list <- lapply(seq(-0.01, 1, length.out = 1000), function(x){
        if(length(unique(pred.ecrins[, mod.name])) == 1 | length(unique(pred.ecrins[, 1])) == 1 ){
          return(data.frame(best.stat = 0, cutoff = 0, sensitivity = 0, specificity = 0))
        }
        biomod2::Find.Optim.Stat(Stat='TSS',
                                 pred.ecrins[, mod.name],
                                 pred.ecrins[, 1],
                                 Fixed.thresh = x)
      })
      eval.test.df <- bind_rows(eval.test.df, data.frame(do.call(rbind, eval.test.list), mod.name = mod.name, row.names = NULL, stringsAsFactors = FALSE))
    }
    
    ## scale variables
    eval.test.df$cutoff <- eval.test.df$cutoff
    eval.test.df$sensitivity <- eval.test.df$sensitivity / 100
    eval.test.df$specificity <- eval.test.df$specificity / 100
    
    eval.test.df <- eval.test.df %>% gather(val.name, val, c(best.stat, sensitivity, specificity))
    
    cat("\n\tproduce evaluation graph")
    gg <- ggplot(data = eval.test.df, aes(x = cutoff, y = val, colour = val.name)) + geom_line() + facet_grid(~mod.name) + coord_cartesian(ylim = c(0,1)) + theme(legend.position="bottom")
    lp <- rasterVis::levelplot(hs.stk, main = paste(pfg_, "-", simul.desc), 
                               layout = c(nlayers(hs.stk),1), colorkey = list(space = "bottom"), par.settings = rasterVis::BuRdTheme)
    png(file.path(path_output, paste0(pfg_, '_TSS_scores_', simul.id,'.png')))
    print(grid.arrange(lp, gg, ncol = 1))
    dev.off()
    
  }
}

