process SUMMARY {
    tag "$meta.id"
    label 'process_single'

    container "${ 'staphb/samtools:1.17' }"

    input:
    tuple val(meta), path(bbduklog), path(bam)

    output:
    path("*.tsv"), emit: summary_tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # raw reads and trimmed reads
    pair_raw_reads=`grep "Input:" ${bbduklog} | awk '{print \$2}'`
    pair_trimmed_reads=`grep "Result:" ${bbduklog} | awk '{print \$2}'`
    raw_reads=\$((pair_raw_reads / 2))
    trimmed_reads=\$((pair_trimmed_reads / 2))
    
    pct_reads_trimmed=\$(python3 -c "print (round((float('\$trimmed_reads') / float('\$raw_reads') * 100), 3))")

    # mapped reads
    mapped_reads=`samtools view -F 4 -c ${bam}`
    pct_reads_mapped=\$(python3 -c "print (round((float('\$mapped_reads') / float('\$raw_reads') * 100), 3))")

    echo "sample_name\traw_reads\ttrimmed_reads\tpct_reads_trimmed\tmapped_reads\tpct_reads_mapped" > ${prefix}.summary.tsv
    echo "${prefix}\t\${raw_reads}\t\${trimmed_reads}\t\${pct_reads_trimmed}\t\${mapped_reads}\t\${pct_reads_mapped}" >> ${prefix}.summary.tsv
    
    """
}
