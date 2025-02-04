##############################################################
####                   Download data                      ####
###############################################################

if(!require(readstata13)) install.packages("data.table", repos = "http://cran.us.r-project.org")
if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")

# Name for url
url <- "https://github.com/LeonelBorjaPlaza/data/raw/main/1_BDD_ENS2018_f1_personas%20-%20Copy.zip"
# Temporal Directory
td <- tempdir()
# Temp file
tf <- tempfile(tmpdir=td, fileext = ".zip")
# Dowload file
download.file(url,tf)

# We get the file name, we unzip ir, and load data
personas.f.name <- unzip(tf, list=TRUE)$Name[1] # El archivo dta personas es el primero
unzip(tf, files=personas.f.name, exdir=td, overwrite=TRUE)
personas.f.path <- file.path(td, personas.f.name)
personas <- read.dta13(personas.f.path)

data.key.personas <- data.frame(variable = names(personas), 
                                label = attr(personas,"var.labels"))

###########################################################
####                   Var creation                   ####
####                   Years of education              ####
###########################################################

edulevel <- as.numeric(personas$f1_s2_19_1)
eduy<- as.numeric(personas$f1_s2_19_2)

#A�OS DE EDUCACI�N "yoe" , 2do de basica=1, bachillerato completo=12

personas <- personas %>% 
  mutate(yoe = case_when(edulevel==1 ~ 0, #ninguno
                         edulevel==2 & eduy>0 & eduy<=3 ~ 2*eduy -1,
                         edulevel==2 & eduy==0 ~ 0,
                         edulevel==2 & eduy>3 & eduy<11 ~ 2 + eduy,
                         edulevel==3 ~ 0, #jard�n de infantes
                         edulevel==4 & eduy>=0 & eduy<7 ~ eduy, #primaria
                         edulevel==5 & eduy>0 & eduy<11 ~ eduy-1, 
                         edulevel==5 & eduy==0 ~ 0,
                         edulevel==6 & eduy>=0 & eduy<7 ~ eduy+6, #secundaria
                         edulevel==7 & eduy>=0 & eduy<4 ~ eduy+9, #bachillerato
                         edulevel==8 ~ eduy+12, #superior no universitario
                         edulevel==9 ~ eduy+12, #universitario 
                         edulevel==10 ~ eduy+16, #posgrado
                         TRUE ~ NA_real_))

####################################################
####                   Height                ####
####################################################

#Height (Following National Instituto of Statistic Code that is in Stata)
#Length of height
personas <- mutate(personas, talla1 = coalesce(f1_s7_5_1,f1_s7_6_1), 
                   talla2 = coalesce(f1_s7_5_2,f1_s7_6_2),
                   talla3 = coalesce(f1_s7_5_3, f1_s7_6_3))

#DIfference in measures
personas <- personas %>%
  mutate(d1=abs(talla1-talla2), d2=abs(talla1-talla3), d3=abs(talla2-talla3))

#Minimum distance among people
personas <- personas %>% mutate(dmin = min(d1,d2,d3))

#Average between 1st and secong measure, if dif <0.5, if not then aveage of the min difference of measures
personas <- personas %>% 
  mutate(estatura = case_when(d1 <= 0.5 ~ (talla1+talla2)/2,
                              dmin==d3 ~ (talla2+talla3)/2,
                              dmin==d2 ~ (talla1+talla3)/2,
                              TRUE ~ (talla1+talla2)/2))

####################################################
####             Labor Income               ####
####################################################

is.element(999999, personas$f1_s3_15) # Observamos que no hay 999999

#NAs to )
ingresos <- personas[, c("f1_s3_15", "f1_s3_16_2", "f1_s3_17", "f1_s3_18", 
                         "f1_s3_19", "f1_s3_20_2", "f1_s3_22_2")]
personas <- personas %>% mutate(inc = rowSums(ingresos, na.rm = TRUE))

#Log labor income
personas <- mutate(personas, linc=ifelse(inc>=1,log(inc),NA))
personas <- mutate(personas, ingrl=ifelse(inc>=0,inc,NA))

####################################################
####           Data for graph                  ####
####################################################
#Variables to use
datos <- personas  %>% select(linc, estatura, sexo, etnia , edadanios, yoe, ingrl)
#No NA
datos <- na.omit(datos)

#only using -3 y 3 sd in height, mestizos, 41 to 49 age
datos <- datos %>% filter(edadanios>40 & edadanios<50 & etnia==3)
sum <- datos %>% group_by(sexo) %>% summarize(p = mean(estatura), sd = sd(estatura))
menp <- sum[[1,2]]
mensd <- sum[[1,3]]
womenp <- sum[[2,2]]
womensd <- sum[[2,3]]

#Normalize height
datos <- mutate(datos, zm=ifelse(sexo=="hombre", (estatura-menp)/mensd, NA))
datos <- mutate(datos, zw=ifelse(sexo=="mujer", (estatura-womenp)/womensd, NA))

#Data fro graph
grafico <- datos[which( (datos$zm>=-3 & datos$zm<=3) | (datos$zw>=-3 & datos$zw<=3)), ]

####################################################
####                  graphs                   ####
####################################################

#Log de income vs height
ggplot(grafico,aes(x=estatura, y=linc, group=sexo)) +
  geom_point(aes(shape = sexo, color = sexo)) +  theme_bw() + ylab("Logaritmo Ingreso Laboral") +
  xlab("Estatura en cm.") 

#Log income Vs height - LOESS(local weighted regression)
ggplot(grafico,aes(x=estatura, y=linc, group=sexo)) +
  geom_smooth(method = "loess" , se=FALSE, aes(linetype = sexo, color = sexo)) +  theme_bw() + ylab("Logaritmo Ingreso Laboral") + xlab("Estatura en cm.")

#Linear Regression
ggplot(grafico,aes(x=estatura, y=linc, group=sexo)) +
  geom_smooth(method = "lm" , se=FALSE, aes(linetype = sexo, color = sexo)) +  theme_bw() + 
  labs(title = "Hola", y = "Ingreso laboral (en log)", x = "Estatura") +
  annotate("text", label = "log_ing=0.43+0.035*estatura", x = 160, y = 6.4, size = 4, colour = "paleturquoise3") +
  annotate("text", label = "log_ing=2.51519+0.022*estatura", x = 175, y = 6, size = 4, colour = "tomato3")

#Years of Education Vs hegiht - Gr�fico de LOESS(local weighted regression)
ggplot(grafico,aes(x=estatura, y=yoe, group=sexo)) +
  geom_smooth(method = "loess" , se=FALSE, aes(linetype = sexo, color = sexo)) + theme_bw() + 
  labs(x = "A�os de educaci�n", y = "Estatura en cm.", title = "Relaci�n a�os de eduaci�n Vs estatura")  +
  theme(plot.title = element_text(color="black", size=14, face="bold.italic"))

####################################################
####                  Regresiones               ####
####################################################

lm(linc~estatura,grafico[which(grafico$sexo=="hombre"),])
lm(linc~estatura,grafico[which(grafico$sexo=="mujer"),])