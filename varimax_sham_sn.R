## loading packages
source('Codes/Functions.R')
source('Codes/FactorAnalysisUtils.R')
Initialize()

qc_variables <- c( "Library_size", "num_expressed_genes","mito_perc" )
strain_info = c('DA', 'DA', 'LEW', 'LEW')

check_qc_cor <- function(merged_samples, pca_embedding_df, main){
  df_cor <- data.frame(pca_embedding_df,
                       Library_size=merged_samples$nCount_RNA,
                       num_expressed_genes=merged_samples$nFeature_RNA, 
                       mito_perc=merged_samples$mito_perc)
  df_cor <- cor(df_cor[,!colnames(df_cor)%in% c('clusters')])
  df_cor_sub <- df_cor[colnames(df_cor)%in%qc_variables, !colnames(df_cor)%in%qc_variables]
  pheatmap(df_cor_sub, fontsize_row=10, main=main, color = magma(20,direction = 1))
}

merged_samples2 = readRDS('~/rat_sham_sn_data/standardQC_results/sham_sn_merged_annot_standardQC.rds')
#merged_samples = readRDS('~/rat_sham_sn_data/standardQC_results/sham_sn_merged_annot_standardQC.rds')

merged_samples2$SCT_snn_res.2.5

####################################################################
#### generating the merged data needed for varimax analysis:
## each sample need to be normalized individually with all the features included
## the normalized samples should be merged and then scaled

####samples need to be normalized individually 
list_files = list.files(path = '~/rat_sham_sn_data/standardQC_results', pattern ='_data_afterQC.rds', include.dirs = T, full.names = T)
files_rds <- lapply(list_files, readRDS)

sample_names = list.files(path = '~/rat_sham_sn_data/standardQC_results', pattern ='_data_afterQC.rds')
sample_names = gsub('_3pr_v3_data_afterQC.rds', '', sample_names)
sample_names = gsub('MacParland__SingleNuc_', '', sample_names)
names(files_rds) =  sample_names
strain = c('DA', 'DA', 'LEW', 'LEW')
########################################
##### Identifying and removing the hep clusters in each samples
i = 4
hep_clusters=list(c(0:4), c(0:5), c(0:5,7,8,11,12), c(0:4))
a_sample_data = files_rds[[i]]

df = data.frame(UMAP_1=getEmb(a_sample_data, 'umap')[,1], 
                UMAP_2=getEmb(a_sample_data, 'umap')[,2],
                cluster=a_sample_data$SCT_snn_res.0.7,
                Alb=GetAssayData(a_sample_data)['Alb',],
                Ptprc=GetAssayData(a_sample_data)['Ptprc',],
                Sparc=GetAssayData(a_sample_data)['Sparc',],
                Lyve1=GetAssayData(a_sample_data)['Lyve1',],
                heps=ifelse(a_sample_data$SCT_snn_res.0.7 %in% hep_clusters[[i]], 'hep', 'other')
                )

names(files_rds)[i]
ggplot(df, aes(UMAP_1, UMAP_2, color=cluster))+geom_point()+theme_classic()+ggtitle(names(files_rds)[i])            
ggplot(df, aes(UMAP_1, UMAP_2, color=Alb))+geom_point()+theme_classic()+scale_color_viridis(direction = -1)+ggtitle('Alb')        
ggplot(df, aes(UMAP_1, UMAP_2, color=Ptprc))+geom_point()+theme_classic()+scale_color_viridis(direction = -1)+ggtitle('Ptprc')  
ggplot(df, aes(UMAP_1, UMAP_2, color=Sparc))+geom_point()+theme_classic()+scale_color_viridis(direction = -1)+ggtitle('Sparc')  
ggplot(df, aes(UMAP_1, UMAP_2, color=Lyve1))+geom_point()+theme_classic()+scale_color_viridis(direction = -1)+ggtitle('Lyve1')  
ggplot(df, aes(UMAP_1, UMAP_2, color=heps))+geom_point()+theme_classic()


########################################
files_rds = sapply(1:length(files_rds), 
                   function(i) {
                     x = files_rds[[i]]
                     x$sample_name = sample_names[i]
                     x$strain = strain[i]
                     
                     # x = x[,!x$SCT_snn_res.0.7 %in% hep_clusters[[i]]]
                     
                     DefaultAssay(x) <- 'RNA'
                     x@assays$SCT <- NULL
                     
                     x = SCTransform(x, conserve.memory=F, verbose=T, return.only.var.genes=F,
                                     variable.features.n = nrow(x[['RNA']]), 
                                     ## according to the paper scaling is not recommended prior to PCA:
                                     ## https://www.biorxiv.org/content/10.1101/576827v2
                                     do.scale = FALSE, ### default value 
                                     do.center = TRUE) ### default value ))
                     
                     x = CreateSeuratObject(GetAssayData(x, assay='SCT'))
                     
                     return(x)
                   },simplify = F)

names(files_rds) = sample_names


merged_samples <- merge(files_rds[[1]], c(files_rds[[2]], files_rds[[3]], files_rds[[4]]), 
                            add.cell.ids = names(files_rds), 
                            project = "single_nuc", 
                            merge.data = TRUE)

dim(merged_samples)
lapply(files_rds, dim)

merged_samples <- ScaleData(merged_samples, features = rownames(merged_samples))  

############ adding metadata calculated using the standard analysis
######## using the complete data
sum(colnames(merged_samples) != colnames(merged_samples2))
rownames(merged_samples@meta.data) == rownames(merged_samples2@meta.data)
merged_samples@meta.data = merged_samples2@meta.data

######## using the non-hepatocyte population
sum(!rownames(merged_samples@meta.data) %in% rownames(merged_samples2@meta.data))
annotated_map_metadata = merged_samples2@meta.data
subset_metadata = merged_samples@meta.data
annotated_map_metadata$id = rownames(annotated_map_metadata)
subset_metadata$id = rownames(subset_metadata)
merged_metadata = merge(subset_metadata,annotated_map_metadata, by.x='id',by.y='id', all.x=T, all.y=F, sort=F)
sum(rownames(merged_samples@meta.data) != merged_metadata$id)  ## order is reserved in the merged dataframe
dim(merged_metadata)
dim(subset_metadata)
merged_samples@meta.data <- merged_metadata
head(merged_samples@meta.data)
# saveRDS(merged_samples, '~/rat_sham_sn_data/standardQC_results/sham_sn_merged_annot_standardQC_allfeatures.rds')


####################################################################
### needed data for the varimax PCA 
merged_samples <- RunPCA(merged_samples, features = rownames(merged_samples))  

loading_matrix = Loadings(merged_samples, 'pca')
# USING RNA is REALLY IMPORTANT. REMOVING THE SCT does not work and seurat obj seems to remember that 
gene_exp_matrix = GetAssayData(merged_samples, assay = 'RNA') 
dim(gene_exp_matrix)
dim(loading_matrix)

rot_data <- get_varimax_rotated(gene_exp_matrix, loading_matrix)
rotatedLoadings <- rot_data$rotLoadings
scores <- data.frame(rot_data$rotScores)
colnames(scores) = paste0('PC_', 1:ncol(scores))
head(scores)
head(rotatedLoadings)
plot(scores[,1], scores[,2]) ### checking if varimax factors look meaningful


embedd_df_rotated <- data.frame(scores)
PCs_to_check = 1:ncol(embedd_df_rotated)
embedd_df_rotated_2 <- embedd_df_rotated[,PCs_to_check]
colnames(embedd_df_rotated_2) <- paste0('Var.PC_', PCs_to_check)


#### adding meta data to the varimax data frame
sum(rownames(merged_samples2@meta.data) != rownames(embedd_df_rotated_2))
embedd_df_rotated_2 = cbind(embedd_df_rotated_2, merged_samples2@meta.data) ### run for the complete data
embedd_df_rotated_2 = cbind(embedd_df_rotated_2, merged_samples@meta.data) ### run for the non-hep data


embedd_df_rotated_2

### saving the varimax results with the added metadata 
#saveRDS(list(scores=embedd_df_rotated_2, rotatedLoadings=rotatedLoadings), 
#        '~/rat_sham_sn_data/standardQC_results/sham_sn_merged_standardQC_varimax_res.rds')


#############
#### Adding updated annotation metadata to the varimax results 
merged_samples$SCT_snn_res.2.5 = as.character(merged_samples2$SCT_snn_res.2.5)
sum(rownames(embedd_df_rotated_2) != colnames(merged_samples2))
embedd_df_rotated_2$clusters = merged_samples$SCT_snn_res.2.5

##### adding the final annotations to the dataframe
annot_info <- read.csv('figure_panel/Annotations_SingleNuc_Rat_June_8_2023.csv')
annot_info <- annot_info[1:35, 1:4]
colnames(annot_info)[1] = 'clusters'

################################################################
########  adding color information to the data frame ##########
###############################################################

fc <- colorRampPalette(c("green", "darkgreen"))
annot_info.df = data.frame(table(annot_info$label))

fc <- colorRampPalette(c('pink1', 'palevioletred1'))
fc <- colorRampPalette(c('palevioletred1'))
cvHep_c = fc(annot_info.df$Freq[annot_info.df$Var1=='Hep 1']) #cvHep

fc <- colorRampPalette(c('orchid1', 'orchid4'))
fc <- colorRampPalette(c('orchid3'))
Hep_c = fc(annot_info.df$Freq[annot_info.df$Var1=='Hep 2'])

#fc <- colorRampPalette(c('palevioletred1', 'palevioletred1'))
fc <- colorRampPalette(c('magenta1', 'magenta3'))
fc <- colorRampPalette(c('maroon1'))
ppHep_c = fc(annot_info.df$Freq[annot_info.df$Var1=='Hep 3']) #ppHep

fc <- colorRampPalette(c('grey70', 'grey20'))
fc <- colorRampPalette(c('mistyrose'))
unknown_c = fc(annot_info.df$Freq[annot_info.df$Var1=='Unknown/High Mito'])

fc <- colorRampPalette(c('cyan')) #coral
chol_c = fc(annot_info.df$Freq[annot_info.df$Var1=='Cholangiocytes'])

infMac_c = '#117733'
nonInfMac_c = '#999933' #'#47A265'
LSEC_c = c('#FFE729','#FFAF13')
Stellate_c = '#6699CC'

color_df = data.frame(colors=c(cvHep_c, Hep_c, ppHep_c, chol_c, nonInfMac_c, infMac_c, Stellate_c, LSEC_c , unknown_c),
                      labels=c( rep('Hep 1',length(cvHep_c)), rep('Hep 2',length(Hep_c)), rep('Hep 3',length(ppHep_c)), 
                                rep('Cholangiocytes',length(chol_c)), 'Non-inf Macs', 'Inf Macs', 'Mesenchymal', 
                                rep('Endothelial',length(LSEC_c)), rep('Unknown/High Mito',length(unknown_c))))



nrow(annot_info)
nrow(color_df)
color_df$labels == annot_info$label
show_col(color_df$colors)
annot_info2 = cbind(annot_info, color_df)
head(annot_info2)

(0:33)[!(0:33) %in% as.numeric(annot_info$clusters)]
########## merging df_umap with annot_info data.frame
embedd_df_rotated_2$umi = rownames(embedd_df_rotated_2)
embedd_df_rotated_2 = merge(embedd_df_rotated_2, annot_info2, by.x='clusters', by.y='clusters', all.x=T, order=F)
#### re-ordering the rows based on UMIs of the initial data
embedd_df_rotated_2 <- embedd_df_rotated_2[match(colnames(merged_samples),embedd_df_rotated_2$umi),]
embedd_df_rotated_2$umi == colnames(merged_samples)
sum(embedd_df_rotated_2$umi != colnames(merged_samples))
embedd_df_rotated_2$label_clust = paste0(embedd_df_rotated_2$label, ' (',embedd_df_rotated_2$clusters, ')')
head(embedd_df_rotated_2)

annot_info2$label_clust = paste0(annot_info2$label, ' (',annot_info2$clusters, ')')

Colors = annot_info2$colors
names(Colors) <- as.character(annot_info2$label)
#names(Colors) <- as.character(annot_info2$label_clust)

embedd_df_rotated_2$sample_name =  merged_samples$sample_name
embedd_df_rotated_2$nuclear_fraction =  merged_samples$nuclear_fraction
embedd_df_rotated_2$nCount_RNA = merged_samples$nCount_RNA
embedd_df_rotated_2$strain = merged_samples$strain

varimax_res = readRDS('~/rat_sham_sn_data/standardQC_results/sham_sn_merged_standardQC_varimax_res2.5_updated_July23.rds')
#saveRDS(list(score=embedd_df_rotated_2, loading=rotatedLoadings),
#          file = '~/rat_sham_sn_data/standardQC_results/sham_sn_merged_standardQC_varimax_res2.5_updated_July23.rds')


loading_df = data.frame(sapply(1:ncol(varimax_res$loading), function(i)varimax_res$loading[,i]))
colnames(loading_df) = paste0('varPC_', 1:ncol(loading_df))
head(loading_df)
write.csv(loading_df, '~/rat_sham_sn_data/standardQC_results/sham_sn_merged_standardQC_varimax_res2.5_loadingDF_updated_July23.csv')


check_qc_cor(merged_samples2, embedd_df_rotated_2[,PCs_to_check], 
             main='Varimax-PC embeddings correlation with technical covariates')

check_qc_cor(merged_samples, embedd_df_rotated_2[,PCs_to_check], 
             main='Varimax-PC embeddings correlation with technical covariates')

pdf('~/rat_sham_sn_data/VarimaxPCA_sham_sn_merged_nonHeps.pdf',width = 14,height=16) 

i = 16
for(i in PCs_to_check){ 
  pc_num = i
  rot_df <- data.frame(Varimax_1=embedd_df_rotated_2$Var.PC_1,
                       emb_val=embedd_df_rotated_2[,(pc_num+1)],
                       #cluster=as.character(merged_samples$final_cluster),
                       cluster=as.character(embedd_df_rotated_2$cluster),
                       label = as.character(embedd_df_rotated_2$labels),
                       label_clust = as.character(embedd_df_rotated_2$label_clust),
                       sample_name=embedd_df_rotated_2$sample_name,
                       strain=embedd_df_rotated_2$strain,
                       nuclear_fraction = embedd_df_rotated_2$nuclear_fraction,
                       nCount_RNA = embedd_df_rotated_2$nCount_RNA)
  
  
  ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=label))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_manual(values=Colors)
  ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=sample_name))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_manual(values=colorPalatte)
  ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=strain))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_manual(values=colorPalatte)
  
  ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=cluster))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_manual(values=Colors)
  
  p4=ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=nuclear_fraction))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_viridis(direction = -1)
  p5=ggplot(rot_df, aes(x=Varimax_1, y=emb_val, color=nCount_RNA))+geom_point()+
    theme_classic()+ylab(paste0('Varimax_',i))+scale_color_viridis(direction = -1)
  
  
  #p5=ggplot(rot_df, aes(x=sample_name, y=emb_val, color=nCount_RNA))+geom_boxplot()+theme_classic()
  gridExtra::grid.arrange(p1,p2,p3,p6,p4,p5,ncol=2,nrow=3)
}
dev.off()  



#####gene_exp_matrix = GetAssayData(merged_samples, assay = 'RNA') 
dim(gene_exp_matrix)
dim(loading_matrix)

########### Evaluating which genes have sample specific expression based on the gene_exp_matrix
sample_info = unlist(lapply(str_split(colnames(gene_exp_matrix), '_'), function(x) paste0(x[[1]],'_', x[[2]],'_', x[[3]]) ))
sample_info_levels = names(table(sample_info))
gene_exp_matrix_split = lapply(1:length(sample_info_levels), function(i) gene_exp_matrix[,sample_info == sample_info_levels[i]])
sample_geneSums = lapply(gene_exp_matrix_split, rowSums)
names(sample_geneSums) = sample_info_levels
norm_gene_sums = do.call(cbind, sample_geneSums)
sum(norm_gene_sums==0) ## some genes have zero expression in at least one sample
norm_gene_sums_bin = data.frame(ifelse(norm_gene_sums>0, 1, 0))
sum(norm_gene_sums_bin==0)
norm_gene_sums_bin$num_sample_exp = rowSums(norm_gene_sums_bin[,1:4])
head(norm_gene_sums_bin)
table(norm_gene_sums_bin$num_sample_exp) #
#1     2     3     4 
#853   735   788 11623 
dim(norm_gene_sums_bin)
dim(merged_samples)
dim(merged_samples2)
sum(!isUnique(rownames(norm_gene_sums_bin))) ### all genes are unique

norm_gene_sums['Itgal',]


########### Evaluating which genes have strain specific expression based on the gene_exp_matrix
sample_info = unlist(lapply(str_split(colnames(gene_exp_matrix), '_'), function(x) paste0(x[[1]]) ))
sample_info_levels = names(table(sample_info))
gene_exp_matrix_split = lapply(1:length(sample_info_levels), function(i) gene_exp_matrix[,sample_info == sample_info_levels[i]])
sample_geneSums = lapply(gene_exp_matrix_split, rowSums)
names(sample_geneSums) = sample_info_levels
norm_gene_sums = do.call(cbind, sample_geneSums)
sum(norm_gene_sums==0) ## some genes have zero expression in at least one sample
norm_gene_sums_bin = data.frame(ifelse(norm_gene_sums>0, 1, 0))
sum(norm_gene_sums_bin==0)
norm_gene_sums_bin$num_sample_exp = rowSums(norm_gene_sums_bin[,1:2])
head(norm_gene_sums_bin)
table(norm_gene_sums_bin$num_sample_exp) #
#1     2 
#1225 12774
dim(norm_gene_sums_bin)
dim(merged_samples)
dim(merged_samples2)
sum(!isUnique(rownames(norm_gene_sums_bin))) ### all genes are unique

strain_specific_genes = rownames(norm_gene_sums_bin)[norm_gene_sums_bin$num_sample_exp == 1]
gene_tocheck = 'Itgal'
gene_tocheck %in% strain_specific_genes
strain_specific_genes[grep('RT', strain_specific_genes)]

norm_gene_sums = data.frame(norm_gene_sums[strain_specific_genes, ])
head(norm_gene_sums[order(norm_gene_sums$DA, decreasing = T), ], 40)
head(norm_gene_sums[order(norm_gene_sums$LEW, decreasing = T), ], 40)


