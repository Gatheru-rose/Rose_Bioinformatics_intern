#!/opt/apps/nextflow/20.10.0/bin/nextflow

//Enable DSL 2 syntax
nextflow.enable.dsl = 2

//Import modules here

include { FASTQC; TRIMMOMATIC; POST_FASTQC } from "./modules/qc.nf" addParams(outdir: "${params.outdir}")
include { USEARCH_MERGE; FILTER; REFERENCEDB; ORIENT; DEREPLICATION; CHIMERA_DETECTION; CLUSTER_OTUS} from "./modules/chimera.nf"
include { OTU_CONVERSION; MAFFT_ALIGNMENT_PLUS; OTUTABLE_TO_ARTIFACT;
          FEATURE_TABLE; CLASSIFIER} from "./modules/artificats.nf"
include { INTRO_DIVERSITY; ALPHA_DIVERSITY; SHANNON_DIVERSITY ; BETA_DIVERSITY ; TAXONOMIC_BARPLOT}from "./modules/visualization.nf"


// set the reads channel
Channel.fromFilePairs( params.reads, checkExists:true )
    .set{ read_pairs_ch }
//read_pairs_ch = Channel.fromPath(params.reads).collect()

Channel.fromPath( params.metadata, checkIfExists:true )
    .set { medata_ch }

Channel.fromPath(params.primers)
    .set { primers_ch }

//Run the main workflow below:
workflow{
    // Quality check and trimming
    // process 1a
    FASTQC(read_pairs_ch)
    //MultiQC_raw(FASTQC.out.collect())
    // process 1b
    TRIMMOMATIC(read_pairs_ch)
    // process 1c
   // POST_FASTQC(TRIMMOMATIC.out)
    //Post_MultiQC(POST_FASTQC.out.collect())

    // Chimera detection and Otu generation
    // step 1
    USEARCH_MERGE(TRIMMOMATIC.out.collect())
    // step 2

    FILTER(USEARCH_MERGE.out.all_reads_merged_fastq, primers_ch)
    // step 3
    REFERENCEDB()
    // step 4
    ORIENT(FILTER.out.filtered_fasta, REFERENCEDB.out)
    //step 5
    DEREPLICATION(ORIENT.out.orient_fasta)
    // step 5
    CHIMERA_DETECTION(DEREPLICATION.out.uniqs_fasta, REFERENCEDB.out)
    // step 6
    CLUSTER_OTUS(DEREPLICATION.out.uniqs_fasta,FILTER.out.filtered_fasta)

    // Qiime2 artefact
    // step 1
    OTU_CONVERSION(CLUSTER_OTUS.out.ASVs_fasta)
    // step 2
    MAFFT_ALIGNMENT_PLUS(OTU_CONVERSION.out.otus_qza)
    // step 3
    OTUTABLE_TO_ARTIFACT(CLUSTER_OTUS.out.ASVcount_txt)
    //step 4
    FEATURE_TABLE(OTUTABLE_TO_ARTIFACT.out, medata_ch)
    //step 5
    CLASSIFIER()

    //VISUALIZATION
    // step 0: Intro_diversity
    INTRO_DIVERSITY(FEATURE_TABLE.out.otutab_qza.combine(medata_ch))

    // step 1: Alpha diversity
    ALPHA_DIVERSITY(INTRO_DIVERSITY.out.combine(medata_ch))

    // step2: Shannon diversity
    SHANNON_DIVERSITY(INTRO_DIVERSITY.out.combine(medata_ch))

    // step3: Beta diversity
    BETA_DIVERSITY(INTRO_DIVERSITY.out.combine(medata_ch))

    // step4: Taxonomic_barplot
    TAXONOMIC_BARPLOT(OTU_CONVERSION.out.otus_qza, FEATURE_TABLE.out.otutab_qza, CLASSIFIER.out, medata_ch)
}
