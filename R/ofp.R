#' Calculate ozone formation potential
#'
#' Calculate Ozone Formation Potential (OFP) of VOC time series.
#'
#' The CAS number was matched for each VOC speices (from column name), and the
#' Maximum Incremental Reactivity (MIR) value was matched through the CAS number and used for time series calculation. \cr
#' The MIR value comes from "Carter, W. P. (2009). Updated maximum incremental
#' reactivity scale and hydrocarbon bin reactivities for regulatory applications.
#' California Air Resources Board Contract, 2009, 339" (revised January 28, 2010).
#'
#' @param df dataframe contains time series.
#' @param colid column index for date-time. The default value is 1.
#' @param unit unit for VOC concentration. A character vector from these options: "ugm" or "ppbv". "ugm" means ug/m3. "ppbv" means part per billion volumn.
#' @param t Temperature, in units k, for conversion from PPB to micrograms per
#' cubic meter. By default, t equals to 25 degrees Celsius.
#' @param p Pressure, in kPa, for converting from PPB to micrograms per cubic
#' meter. By default, p equals to 101.325 kPa.
#' @param sortd logical value. It determines whether the VOC species 
#' are sorted or not. By default, sortd has value "TRUE". 
#' If TRUE, VOC species in time series will be arranged according to VOC group,
#'  relative molecular weight, and MIR value.
#' @param colid column index for date-time. The default value is 1.
#' @return  a list contains 2 tables: results for matched MIR values and OFP time series.
#' @export
#' @examples
#' ofp(voc)
#' @importFrom utils URLencode
#' @importFrom xml2 read_html

ofp <- function(df, unit = "ppbv", t = 25, p = 101.325, sortd =TRUE, colid = 1){
  #set colid
  if(colid != 1){
    df[,c(1,colid)] = df[,c(colid,1)]
    colnames(df)[c(1,colid)] = colnames(df)[c(colid,1)]
  }
  
  #In case df is not a dataframe.
  temp_col_name <- colnames(df)
  df <- data.frame(df,stringsAsFactors = FALSE)
  colnames(df) <- temp_col_name
   
  #get VOC name by colnames of df
  #if read from xlsx, replace "X" and "."
  colnm_df = colnames(df)[2:ncol(df)]
  chemicalnames = ifelse(substr(colnm_df, 1, 1) == "X", sub("^.", "", colnm_df), colnm_df)
  chemicalnames = gsub("\\.", "-", chemicalnames)
  #if i-
  chemicalnames = gsub("\\i-", "iso-", chemicalnames)
  
  #build name_df
  name_df = data.frame(name = chemicalnames,CAS = NA, Source = NA, Matched_Name = NA, MIR = NA, MW = NA, Group = NA, stringsAsFactors = FALSE)

  #search VOC name to get CAS Number from different sources, add cas, sources, mathed_name to name_df
  ##firstly by NIST
  for( i in 1:nrow(name_df)){
    str <- name_df[i,1]
    str <- URLencode(str)
    url=paste(c("https://webbook.nist.gov/cgi/cbook.cgi?Name=", str,"&Units=SI"), collapse='')
    download.file(url, destfile = "scrapedpage.html", quiet=TRUE)
    web <- read_html("scrapedpage.html")
    result_test<-web%>%html_nodes("h1")%>%html_text()
    if(result_test[2] == "Name Not Found"){
      name_df[i,2]="Name Not Found"
      name_df[i,3]=NA
    }else if(result_test[2] == "Search Results"){
      name_df[i,2]="More than 1 result"
      name_df[i,3]=NA
	}else if(grepl("structure unspecified",result_test[2])){
	  name_df[i,2]="structure unspecified in NIST"
	  name_df[i,3]=NA
    }else{
      result_test<-web%>%html_nodes("li")%>%html_text()
      result_test<-strsplit(result_test[21], ": ")
      name_df[i,2]=result_test[[1]][2]
      name_df[i,3]="NIST"
    }
  }

  #match mir by different sources
  ##get CAS from NIST, match name by CAS
  a=lapply(name_df$CAS[which(name_df$Source=="NIST"&!is.na(name_df$CAS))], function(i) grep(i, datacas$CAS))
  a=unlist(lapply(a,function(x) if(identical(x,integer(0))) ' ' else x))
  name_df$MIR[which(name_df$Source=="NIST"&!is.na(name_df$CAS))] = datacas$New[as.numeric(a)]
  name_df$Matched_Name[which(name_df$Source=="NIST"&!is.na(name_df$CAS))] = datacas$Description[as.numeric(a)]
  name_df$MW[which(name_df$Source=="NIST"&!is.na(name_df$CAS))] = datacas$MWt[as.numeric(a)]
  name_df$Group[which(name_df$Source=="NIST"&!is.na(name_df$CAS))] = datacas$Group[as.numeric(a)]


  #if it is matched by CAS in NIST and matched by name in Carter paper, but it doesn't have CAS in Carter paper.
  for(k in which(!is.na(name_df$Source)&is.na(name_df$MIR))){
    tarlist=gsub(" ", "", tolower(datacas$Description), fixed = TRUE)
    tar=tolower(name_df$name[k])
    df_null=data.frame(datacas[tarlist %in% tar,])
    if(nrow(df_null)!=0){
      name_df$Matched_Name[as.numeric(k)] = df_null$Description[1]
      #name_df$CAS[as.numeric(k)] = df_null$CAS[1]
      name_df$MIR[as.numeric(k)] = df_null$New[1]
      name_df$Source[as.numeric(k)] = "CAS is found in NIST. But it only has name in Carter paper 2010"
      name_df$MW[as.numeric(k)] = df_null$MWt[1]
	  name_df$Group[as.numeric(k)] = df_null$Group[1]
    }
  }

  #if it isn't found in NIST, but its name is matched by Carter paper.
  for(k in which(is.na(name_df$Source))){
    tarlist=gsub(" ", "", tolower(datacas$Description), fixed = TRUE)
    tar=tolower(name_df$name[k])
    df_null=data.frame(datacas[tarlist %in% tar,])
    if(nrow(df_null)!=0){
      name_df$Matched_Name[as.numeric(k)] = df_null$Description[1]
      name_df$CAS[as.numeric(k)] = df_null$CAS[1]
      name_df$MIR[as.numeric(k)] = df_null$New[1]
      name_df$Source[as.numeric(k)] = "Carter paper 2010"
      name_df$MW[as.numeric(k)] = df_null$MWt[1]
	  name_df$Group[as.numeric(k)] = df_null$Group[1]
    }
  }
  
  #set GROUP to Unknown for NA group
  name_df$Group[is.na(name_df$Group)] = "Unknown"
  
  #set GROUP to BVOC for BVOC group  
  name_df$Group[name_df$CAS %in% c('80-56-8','127-91-3','78-79-5')] = "BVOC"
  
  #raw_order
  name_df$raw_order = seq.int(nrow(name_df))
  
  #set order for voc species in df and name_df
  if(sortd==TRUE){
	  #order by 2 columns
	  name_df$Group <- factor(name_df$Group, levels = c("Alkanes", "Alkenes", "BVOC", "Alkynes", "Aromatic_Hydrocarbons", "Oxygenated_Organics", "Other_Organic_Compounds", "Unknown"))
	  name_df = name_df[with(name_df, order(Group, MW, MIR)), ]
	  df[,2:ncol(df)]=df[,name_df$raw_order+1]
	  colnames(df)[2:ncol(df)]=colnames(df)[name_df$raw_order+1]
  }
  
  #set concentration df, multiple df with MIR in name_df
  ofp_df = df
  r = 22.4*(273.15+t)*101.325/(273.15*p)
  if(unit=="ugm"){
    Con_ugm = df
	Con_ppbv = Con_ugm
	Con_ppbv[,2:ncol(Con_ugm)] = data.frame(sapply(2:ncol(Con_ugm),function(x) Con_ugm[,x]*as.numeric(r/name_df$MW)[x-1]))	
	ofp_df[,2:ncol(ofp_df)] = data.frame(sapply(2:ncol(df),function(x) df[,x] * as.numeric(name_df$MIR)[x-1]))    
  }else if(unit=="ppbv"){
    Con_ppbv = df
	Con_ugm = Con_ppbv
	Con_ugm[,2:ncol(Con_ppbv)] = data.frame(sapply(2:ncol(Con_ppbv),function(x) Con_ppbv[,x]*as.numeric(name_df$MW/r)[x-1]))
    ofp_df[,2:ncol(ofp_df)] = data.frame(sapply(2:ncol(df),function(x) df[,x] * as.numeric(name_df$MIR*name_df$MW/r)[x-1]))
  }else{
    print("unit error")
  }
  
  #vector of group names
  gn_list = c("Alkanes", "Alkenes", "BVOC", "Alkynes", "Aromatic_Hydrocarbons", "Oxygenated_Organics", "Other_Organic_Compounds", "Unknown")
  
  #generate group df
  Con_ppbv_group=data.frame(Time=df[,1], Alkanes=NA, Alkenes_exclude_BVOC=NA, BVOC=NA, Alkynes=NA, Aromatic_Hydrocarbons=NA, Oxygenated_Organics=NA, Other_Organic_Compounds=NA, Unknown=NA)
  Con_ugm_group=data.frame(Time=df[,1], Alkanes=NA, Alkenes_exclude_BVOC=NA, BVOC=NA, Alkynes=NA, Aromatic_Hydrocarbons=NA, Oxygenated_Organics=NA, Other_Organic_Compounds=NA, Unknown=NA)
  ofp_df_group=data.frame(Time=df[,1], Alkanes=NA, Alkenes_exclude_BVOC=NA, BVOC=NA, Alkynes=NA, Aromatic_Hydrocarbons=NA, Oxygenated_Organics=NA, Other_Organic_Compounds=NA, Unknown=NA)
  
  #sum up columns
  for(gn in 1:length(gn_list)){
	gn_sub_index = which(name_df$Group == gn_list[gn])
	if(length(gn_sub_index)!=0){
		if(length(gn_sub_index)==1){
			Con_ppbv_group[,gn+1]=Con_ppbv[,gn_sub_index+1]
			Con_ugm_group[,gn+1]=Con_ugm[,gn_sub_index+1]
			ofp_df_group[,gn+1]=ofp_df[,gn_sub_index+1]
		}else{
			Con_ppbv_group[,gn+1]=rowSums(Con_ppbv[,gn_sub_index+1], na.rm=TRUE) *NA^!rowSums(!is.na(Con_ppbv[,gn_sub_index+1]))			
			Con_ugm_group[,gn+1]=rowSums(Con_ugm[,gn_sub_index+1], na.rm=TRUE) *NA^!rowSums(!is.na(Con_ugm[,gn_sub_index+1]))
			ofp_df_group[,gn+1]=rowSums(ofp_df[,gn_sub_index+1], na.rm=TRUE) *NA^!rowSums(!is.na(ofp_df[,gn_sub_index+1]))
		}
	}
  }
  
  #Con_ugm_mean
  Con_ugm_mean=data.frame(species=row.names(statdf(Con_ugm)[-1,]),mean=as.numeric(as.character(statdf(Con_ugm,n = 6)[-1,1])))
  Con_ugm_mean$Proportion=Con_ugm_mean$mean/sum(as.numeric(as.character(statdf(Con_ugm,n = 6)[-1,1])),na.rm = TRUE)
  Con_ugm_mean$Proportion=round(Con_ugm_mean$Proportion,4)
  Con_ugm_mean=Con_ugm_mean[with(Con_ugm_mean, order(-mean)), ]
  
  #Con_ppbv_mean
  Con_ppbv_mean=data.frame(species=row.names(statdf(Con_ppbv)[-1,]),mean=as.numeric(as.character(statdf(Con_ppbv,n = 6)[-1,1])))
  Con_ppbv_mean$Proportion=Con_ppbv_mean$mean/sum(as.numeric(as.character(statdf(Con_ppbv,n = 6)[-1,1])),na.rm = TRUE)
  Con_ppbv_mean$Proportion=round(Con_ppbv_mean$Proportion,4)
  Con_ppbv_mean=Con_ppbv_mean[with(Con_ppbv_mean, order(-mean)), ]
  
  #ofp_df_mean
  ofp_df_mean=data.frame(species=row.names(statdf(ofp_df)[-1,]),mean=as.numeric(as.character(statdf(ofp_df,n = 6)[-1,1])))
  ofp_df_mean$Proportion=ofp_df_mean$mean/sum(as.numeric(as.character(statdf(ofp_df,n = 6)[-1,1])),na.rm = TRUE)
  ofp_df_mean$Proportion=round(ofp_df_mean$Proportion,4)
  ofp_df_mean=ofp_df_mean[with(ofp_df_mean, order(-mean)), ]
  
  #Con_ugm_group_mean
  Con_ugm_group_mean=data.frame(species=row.names(statdf(Con_ugm_group)[-1,]),mean=as.numeric(as.character(statdf(Con_ugm_group,n = 6)[-1,1])))
  Con_ugm_group_mean$Proportion=Con_ugm_group_mean$mean/sum(as.numeric(as.character(statdf(Con_ugm_group,n = 6)[-1,1])),na.rm = TRUE)
  Con_ugm_group_mean$Proportion=round(Con_ugm_group_mean$Proportion,4)
  Con_ugm_group_mean=Con_ugm_group_mean[with(Con_ugm_group_mean, order(-mean)), ]
  
  #Con_ppbv_group_mean
  Con_ppbv_group_mean=data.frame(species=row.names(statdf(Con_ppbv_group)[-1,]),mean=as.numeric(as.character(statdf(Con_ppbv_group,n = 6)[-1,1])))
  Con_ppbv_group_mean$Proportion=Con_ppbv_group_mean$mean/sum(as.numeric(as.character(statdf(Con_ppbv_group,n = 6)[-1,1])),na.rm = TRUE)
  Con_ppbv_group_mean$Proportion=round(Con_ppbv_group_mean$Proportion,4)
  Con_ppbv_group_mean=Con_ppbv_group_mean[with(Con_ppbv_group_mean, order(-mean)), ]
  
  #ofp_df_group_mean
  ofp_df_group_mean=data.frame(species=row.names(statdf(ofp_df_group)[-1,]),mean=as.numeric(as.character(statdf(ofp_df_group,n = 6)[-1,1])))
  ofp_df_group_mean$Proportion=ofp_df_group_mean$mean/sum(as.numeric(as.character(statdf(ofp_df_group,n = 6)[-1,1])),na.rm = TRUE)
  ofp_df_group_mean$Proportion=round(ofp_df_group_mean$Proportion,4)
  ofp_df_group_mean=ofp_df_group_mean[with(ofp_df_group_mean, order(-mean)), ]
  
  
  #results
  results <- list(
	Con_ugm = Con_ugm,
	Con_ugm_mean = Con_ugm_mean, 
	Con_ugm_group = Con_ugm_group,
	Con_ugm_group_mean = Con_ugm_group_mean,
	Con_ppbv = Con_ppbv,
	Con_ppbv_mean = Con_ppbv_mean,
	Con_ppbv_group = Con_ppbv_group,
	Con_ppbv_group_mean = Con_ppbv_group_mean,
	MIR_Result = name_df,
	OFP_Result = ofp_df,
	OFP_Result_mean = ofp_df_mean,
	OFP_Result_group = ofp_df_group,
	OFP_Result_group_mean = ofp_df_group_mean
  )
  return(results)
}
