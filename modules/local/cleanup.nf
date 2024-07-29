process CLEANUP {
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'nf-core/ubuntu:20.04' }"

    input:
    path summary_tsv_files
    path summary_tsv_rgi_files
    val  is_failed_summary


    output:
    path "summary*.tsv", emit: summary


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def summary_file_name = is_failed_summary ? "summary_failed.tsv" : "summary.tsv"
    """
    echo "sample_name\traw_reads\ttrimmed_reads\tpct_reads_trimmed\tmapped_reads\tpct_reads_mapped" > $summary_file_name
    awk '(NR == 2) || (FNR > 1)' *.summary.tsv >> $summary_file_name

    echo "sample\tORF_ID\tContig\tStart\tStop\tOrientation\tCut_Off\tPass_Bitscore\tBest_Hit_Bitscore\tBest_Hit_ARO\tBest_Identities\tARO\tModel_type\tSNPs_in_Best_Hit_ARO\tOther_SNPs\tDrug Class\tResistance Mechanism\tAMR Gene Family\tPredicted_DNA\tPredicted_Protein\tCARD_Protein_Sequence\tPercentage Length of Reference Sequence\tID\tModel_ID\tNudged\tNote\tHit_Start\tHit_End\tAntibiotic" > summary_rgi.tsv
    awk '(NR == 2) || (FNR > 1)' *_rgi_summary.txt >> summary_rgi.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cleanup: ubuntu:20.04
    END_VERSIONS
    """
}
