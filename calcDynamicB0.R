# set working directory to Source File Location

library(ggplot2)

calcDynamicB0 <- function(asap){
  nyears <- asap$parms$nyears
  nages <- asap$parms$nages
  
  NAA <- matrix(NA, nrow = nyears, ncol = nages)
  dynB0 <- rep(NA, nyears)
  
  NAA[1, ] <- asap$N.age[1, ]
  dynB0[1] <- sum(NAA[1, ] * exp(-asap$options$frac.yr.spawn * asap$M.age[1, ]) * 
                    asap$maturity[1, ] * asap$WAA.mats$WAA.ssb[1, ])
  
  for (iy in 2:nyears){
    erec <- asap$SR.parms$SR.alpha * dynB0[iy-1] / (asap$SR.parms$SR.beta + dynB0[iy-1])
    NAA[iy] <- erec * exp(asap$SR.resids$logR.dev[iy])
    for (ia in 2:nages){
      NAA[iy, ia] <- NAA[iy-1, ia-1] * exp(-asap$M.age[iy-1, ia-1])
    }
    NAA[iy, nages] <- NAA[iy, nages] + NAA[iy-1, nages] * exp(-asap$M.age[iy-1, nages])
    dynB0[iy] <- sum(NAA[iy, ] * exp(-asap$options$frac.yr.spawn * asap$M.age[iy, ]) * 
                       asap$maturity[iy, ] * asap$WAA.mats$WAA.ssb[iy, ])
    
  }
  return(dynB0)
}

# steepness values used
mysteep <- c(0.4, 0.6, 0.8, 1.0)

# get the four ASAP runs, only difference among them is the value steepness fixed at
asap04 <- dget("steep04.rdat")
asap06 <- dget("steep06.rdat")
asap08 <- dget("steep08.rdat")
asap10 <- dget("steep10.rdat")

# they have the same objective function value, SSB within 0.1 mt, and R within 1000 fish
c(asap04$like$lk.total, asap06$like$lk.total, asap08$like$lk.total, asap10$like$lk.total)
max(abs(asap04$SSB - asap10$SSB))
max(abs(asap06$SSB - asap10$SSB))
max(abs(asap08$SSB - asap10$SSB))
max(abs(asap04$N.age[, 1] - asap10$N.age[, 1]))
max(abs(asap06$N.age[, 1] - asap10$N.age[, 1]))
max(abs(asap08$N.age[, 1] - asap10$N.age[, 1]))

# but R0 differs widely
cbind(mysteep, c(asap04$SR.parms$SR.R0, asap06$SR.parms$SR.R0, asap08$SR.parms$SR.R0, asap10$SR.parms$SR.R0))

# make SR plot showing the four fits
nyears <- asap04$parms$nyears
srdatdf <- data.frame(SSB = asap10$SSB[1:(nyears-1)],
                      Recruits = asap10$N.age[2:nyears, 1])
npoints <- 1000
ssb04 <- seq(0, asap04$SR.parms$SR.S0, length.out = npoints)
r04 <- asap04$SR.parms$SR.alpha * ssb04 / (asap04$SR.parms$SR.beta + ssb04)
ssb06 <- seq(0, asap06$SR.parms$SR.S0, length.out = npoints)
r06 <- asap06$SR.parms$SR.alpha * ssb06 / (asap06$SR.parms$SR.beta + ssb06)
ssb08 <- seq(0, asap08$SR.parms$SR.S0, length.out = npoints)
r08 <- asap08$SR.parms$SR.alpha * ssb08 / (asap08$SR.parms$SR.beta + ssb08)
ssb10 <- seq(0, asap10$SR.parms$SR.S0, length.out = npoints)
r10 <- asap10$SR.parms$SR.alpha * ssb10 / (asap10$SR.parms$SR.beta + ssb10)
r10[1] <- 0 # by definition, replaces calculated NaN

srdf <- data.frame(steep = as.factor(rep(mysteep, each = npoints)),
                   SSB = c(ssb04, ssb06, ssb08, ssb10),
                   Recruits = c(r04, r06, r08, r10))

srplot <- ggplot(srdf, aes(x=SSB, y=Recruits)) +
  geom_line(aes(group=steep, color=steep)) +
  geom_point(data=srdatdf, aes(x=SSB, y=Recruits)) +
  theme_bw()
print(srplot)
ggsave("srplot.png")

# calculate dynamic B0 for each run
steep04B0 <- calcDynamicB0(asap04)
steep06B0 <- calcDynamicB0(asap06)
steep08B0 <- calcDynamicB0(asap08)
steep10B0 <- calcDynamicB0(asap10)

# make data frame for plotting
nyears <- asap04$parms$nyears
years <- seq(asap04$parms$styr, asap04$parms$endyr)
sdf <- data.frame(Year = rep(years, 4),
                  steep = as.factor(rep(mysteep, each=nyears)),
                  dynB0 = c(steep04B0, steep06B0, steep08B0, steep10B0),
                  SSB = c(asap04$SSB, asap06$SSB, asap08$SSB, asap10$SSB),
                  reldynB0 = c(steep04B0 / steep04B0[1],
                               steep06B0 / steep06B0[1],
                               steep08B0 / steep08B0[1],
                               steep10B0 / steep10B0[1]),
                  relSSB = c(asap04$SSB / asap04$SSB[1],
                             asap06$SSB / asap06$SSB[1],
                             asap08$SSB / asap08$SSB[1],
                             asap10$SSB / asap10$SSB[1]))

ssbplot <- ggplot(sdf, aes(x=Year, y=dynB0, group=steep, color=steep)) +
  geom_line() +
  geom_line(aes(x=Year, y=SSB, group=steep, color=steep), size=1.5) +
  facet_wrap(steep~., scales = "free_y") +
  ylab("SSB") +
  theme_bw()
print(ssbplot)
ggsave("ssbplot.png")

relssbplot <- ggplot(sdf, aes(x=Year, y=reldynB0, group=steep, color=steep)) +
  geom_line() +
  geom_line(aes(x=Year, y=relSSB, group=steep, color=steep), size=1.5) +
  ylab("Relative SSB") +
  theme_bw()
print(relssbplot)
ggsave("relssbplot.png")

# get most recent year depletion using dynamic B0 approach
curr04 <- asap04$SSB[nyears] / steep04B0[nyears]
curr06 <- asap04$SSB[nyears] / steep06B0[nyears]
curr08 <- asap04$SSB[nyears] / steep08B0[nyears]
curr10 <- asap04$SSB[nyears] / steep10B0[nyears]

mytab <- cbind(mysteep, round(c(curr04, curr06, curr08, curr10), 3))
colnames(mytab) <- c("Steepness", "Current Depletion")
mytab
