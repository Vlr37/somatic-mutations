workflow sommut_workflow{
    Array[File] reads
    Array[String] adapters

    Int threads

    File reference
    File reference_fai
    File reference_dict

    String results_folder


    call report as initial_report_1_call {
      input:
        sampleName = basename(reads[0], ".fastq.gz"),
        file = reads[0]
      }

    call report as initial_report_2_call {
      input:
        sampleName = basename(reads[1], ".fastq.gz"),
        file = reads[1]
      }

    call copy as copy_initial_quality_reports {
    input:
        files = [initial_report_1_call.out, initial_report_2_call.out],
        destination = results_folder + "/quality/initial/"
    }

    call atropos_illumina_trim as atropos_illumina_trim_call {
      input:
        reads = reads,
        adapters = adapters,
        threads = threads
    }

    call copy as copy_trimmed {
    input:
        files = [atropos_illumina_trim_call.out1, atropos_illumina_trim_call.out2],
        destination = results_folder + "/trimmed/"
    }

    call report as final_report_1_call {
        input:
          sampleName = basename(atropos_illumina_trim_call.out1, ".fastq.gz"),
          file = atropos_illumina_trim_call.out1
        }

    call report as final_report_2_call {
        input:
          sampleName = basename(atropos_illumina_trim_call.out2, ".fastq.gz"),
          file = atropos_illumina_trim_call.out2
        }

    call copy as copy_cleaned_quality_reports {
    input:
        files = [final_report_1_call.out, final_report_2_call.out],
        destination = results_folder + "/quality/cleaned/"
    }


    call minimap2 {
        input:
            reads = atropos_illumina_trim_call.out,
            reference = reference
    }

    call samtools_conversion {
        input:
            sam = minimap2.out
    }

    call picard_readgroups_sort {
        input:
            bam = samtools_conversion.out
    }

    call picard_validation as picard_validation {
        input:
            bam = picard_readgroups_sort.out
    }

    call picard_indexbam as picard_indexbam {
        input:
            bam = picard_readgroups_sort.out
    }

    call mutect2 {
        input:
            bam = picard_readgroups_sort.out,
            bai = picard_indexbam.out,
            reference = reference,
            referencefai = reference_fai,
            referencedict = reference_dict
    }

    call copy as copy_mutect {
        input:
            files = mutect2.out,
            destination = results_folder
    }

}


task atropos_illumina_trim {
  Array[File] reads
  Array[String] adapters
  Int threads
  Int q = 18
  Int e = 0.1

  command {
    atropos trim \
    -a ${adapters[0]} \
    -A ${adapters[1]} \
    -pe1 ${reads[0]} \
    -pe2 ${reads[1]} \
    -o ${basename(reads[0], ".fastq.gz")}_trimmed.fastq.gz \
    -p ${basename(reads[1], ".fastq.gz")}_trimmed.fastq.gz \
    --minimum-length 35 \
    --aligner insert \
    -q ${q} \
    -e ${e} \
    --threads ${threads} \
    --correct-mismatches liberal
  }

  runtime {
    docker: "jdidion/atropos@sha256:c2018db3e8d42bf2ffdffc988eb8804c15527d509b11ea79ad9323e9743caac7"
  }

  output {
    Array[File] out = [basename(reads[0], ".fastq.gz") + "_trimmed.fastq.gz",  basename(reads[1], ".fastq.gz") + "_trimmed.fastq.gz"]
  }
}

task minimap2 {
    Array[File] reads
    File reference

    command {
        minimap2 \
        -ax \
        sr \
        -L \
        ${reference} \
        ${reads[0]} \
        ${reads[1]} \
        > aln.sam
    }

    runtime {
        docker: "genomicpariscentre/minimap2@sha256:536d7cc40209d4fd1b700ebec3ef9137ce1d9bc0948998c28b209a39a75458fa"
      }
    output {
      File out1 = "aln.sam"
    }
}

task samtools_conversion {
    File sam

    command {
        samtools \
        view \
        -bS \
        ${sam} \
        > aln.bam
    }

    runtime {
        docker: "biocontainers/samtools@sha256:6644f6b3bb8893c1b10939406bb9f9cda58da368100d8c767037558142631cf3"
      }

    output {
        File out = "aln.bam"
      }

}

task picard_readgroups_sort {
    File bam

    command {
        picard AddOrReplaceReadGroups \
        I= ${bam} \
        O= aln2.bam \
        RGID=4 \
        RGLB=lib1 \
        RGPL=illumina \
        RGPU=unit1 \
        RGSM=20 \
	    SORT_ORDER=coordinate
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
      }

    output {
        File out = "aln2.bam"
      }

}

task picard_validation {
    File bam

    command {
        picard ValidateSamFile \
        I=${bam} \
        O=log.txt \
        MODE=SUMMARY
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
      }

    output {
        File out = "log.txt"
      }

}

task picard_indexbam {
    File bam

    command {
        picard BuildBamIndex \
        INPUT=${bam}
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
      }

    output {
        File out = "aln2.bai"
      }

}

task mutect2 {
    File bam
    File bai
    File reference
    File reference_fai
    File reference_dict

    command {
        java -jar /usr/GenomeAnalysisTK.jar \
        -T MuTect2 \
        -R ${reference} \
        -I:tumor ${bam} \
        -nct 7 \
        --artifact_detection_mode \
        -o variants.vcf
    }

    runtime {
        docker: "broadinstitute/gatk3@sha256:5ecb139965b86daa9aa85bc531937415d9e98fa8a6b331cb2b05168ac29bc76b"
      }

    output {
        File out = "variants.vcf"
      }

}


task fastp {

    Array[File] reads

    command {
        fastp --cut_by_quality5 --cut_by_quality3 --trim_poly_g --overrepresentation_analysis \
            -i ${reads[0]} -o ${basename(reads[0], ".fastq.gz")}_cleaned.fastq.gz \
            --correction -I ${reads[1]} -O ${basename(reads[1], ".fastq.gz")}_cleaned.fastq.gz
    }

    runtime {
        docker: "quay.io/biocontainers/fastp@sha256:1ae5d7ce7801391d9ed8622d7208fd7b0318a3e0c1431a039d3498d483742949" #:0.19.3--hd28b015_0
    }

    output {
        File report_json = "fastp.json"
        File report_html = "fastp.html"
        Array[File] reads_cleaned = [basename(reads[0], ".fastq.gz") + "_cleaned.fastq.gz", basename(reads[1], ".fastq.gz") + "_cleaned.fastq.gz"]
    }
}

task report {

  String sampleName
  File file

  command {
    /opt/FastQC/fastqc ${file} -o .
  }

  runtime {
    docker: "quay.io/ucsc_cgl/fastqc@sha256:86d82e95a8e1bff48d95daf94ad1190d9c38283c8c5ad848b4a498f19ca94bfa"
  }

  output {
    File out = sampleName+"_fastqc.zip"
  }
}

task copy {
    Array[File] files
    String destination

    command {
        mkdir -p ${destination}
        cp -L -R -u ${sep=' ' files} ${destination}
    }

    output {
        Array[File] out = files
    }
}
