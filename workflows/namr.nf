/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowNamr.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                              } from '../modules/nf-core/fastqc/main'
include { MULTIQC                             } from '../modules/nf-core/multiqc/main'
include { FASTQC as FASTQC_TRIM               } from '../modules/nf-core/fastqc/main'
include { MULTIQC as MULTIQC_TRIM             } from '../modules/nf-core/multiqc/main'
include { FASTQC as FASTQC_UNCLASSIFIED       } from '../modules/nf-core/fastqc/main'
include { MULTIQC as MULTIQC_UNCLASSIFIED     } from '../modules/nf-core/multiqc/main'
include { BBMAP_BBDUK                         } from '../modules/nf-core/bbmap/bbduk/main'
include { BBMAP_ALIGN                         } from '../modules/local/bbmap.nf'  
include { BBMAP_REPAIR                        } from '../modules/local/repair.nf'
include { BBMAP_REPAIR as REPAIR_INITIAL      } from '../modules/local/repair.nf'
include { SEQTK_SAMPLE                        } from '../modules/nf-core/seqtk/sample/main'
include { KRAKEN2_KRAKEN2                     } from '../modules/nf-core/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_REPORT   } from '../modules/nf-core/kraken2/kraken2/main'
include { BOWTIE2_ALIGN                       } from '../modules/nf-core/bowtie2/align/main'
include { BOWTIE2_BUILD                       } from '../modules/nf-core/bowtie2/build/main'
include { SPADES                              } from '../modules/nf-core/spades/main'
include { RGI_MAIN                            } from '../modules/nf-core/rgi/main/main'
include { GUNZIP                              } from '../modules/nf-core/gunzip/main'
include { SUMMARY                             } from '../modules/local/summary.nf'  
include { CLEANUP as FINAL                    } from '../modules/local/cleanup.nf'  


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow NAMR {

    ch_versions = Channel.empty()

    INPUT_CHECK (
        file(params.input)
    )

    ch_raw_reads = INPUT_CHECK.out.reads

    BOWTIE2_BUILD (
        Channel.of([:]).combine([file(params.ref)])
    )

    ch_bowtie2_index = BOWTIE2_BUILD.out.index.map{ [it[1]] }

    if (params.sub_sample) {
        SEQTK_SAMPLE (
            ch_raw_reads.combine([params.sample_size])
        )
        ch_raw_reads = SEQTK_SAMPLE.out.reads
    }    

    REPAIR_INITIAL (
        ch_raw_reads
    )

    BBMAP_BBDUK (
        REPAIR_INITIAL.out.fastqs,
        []
    )
/*
    BBMAP_BBDUK (
        ch_raw_reads,
        []
    )
*/

    FASTQC (
        BBMAP_BBDUK.out.reads
    )

    MULTIQC (
        FASTQC.out.zip.collect{it[1]}.ifEmpty([]),
        [],
        [],
        []
    )    

    KRAKEN2_KRAKEN2 (
        BBMAP_BBDUK.out.reads,
        params.kraken_host_db,
        true,  // save fastqs
        false  // don't report      
    )    
/*
    if (params.kraken_standard_db) {

        REPAIR_INITIAL (
            INPUT_CHECK.out.reads
        )

        BBMAP_BBDUK (
            REPAIR_INITIAL.out.fastqs,
            []
        )        

        KRAKEN2_REPORT (
            //KRAKEN2_KRAKEN2.out.unclassified_reads_fastq,
            BBMAP_BBDUK.out.reads,
            params.kraken_standard_db,
            false,  // save fastqs
            false  // classified reads report      
        )

        FASTQC_UNCLASSIFIED (
            //KRAKEN2_KRAKEN2.out.unclassified_reads_fastq,
            BBMAP_BBDUK.out.reads,
        )

        MULTIQC_UNCLASSIFIED (
            FASTQC_UNCLASSIFIED.out.zip.collect{it[1]}.ifEmpty([]),
            [],
            [],
            []
        )
    }
*/
    BBMAP_REPAIR (
        KRAKEN2_KRAKEN2.out.unclassified_reads_fastq,
    )

	BOWTIE2_ALIGN (
        BBMAP_REPAIR.out.fastqs,
        BBMAP_REPAIR.out.fastqs.map { [it[0]] }.combine(ch_bowtie2_index),
        false,  // don't save_unaligned, i.e. non-host reads
        true  //sort aligned reads 
	)

    BBMAP_ALIGN (
        BBMAP_REPAIR.out.fastqs,
        file(params.card_ref)
    )

    SPADES (
        BBMAP_ALIGN.out.fastqs.map { [it[0], it[1], [], []]},  // no pacbio, no nanopore
        [], // no yaml
        []  // no hmm
    )

    GUNZIP (
        SPADES.out.scaffolds
    )

    RGI_MAIN (
        GUNZIP.out.gunzip,
        params.rgi_card_path,
        []
    )

    BBMAP_BBDUK.out.log
        .join(BOWTIE2_ALIGN.out.bam)
        .map { meta, bbduklog, bam -> [ meta, bbduklog, bam ] }
        .set {ch_summary}

    SUMMARY (
        ch_summary
    )

    FINAL ( 
        SUMMARY.out.summary_tsv.collect(),
        RGI_MAIN.out.tsv.map{ it[1] }.collect(),
        false
    )        

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
