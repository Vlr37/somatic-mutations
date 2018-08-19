workflow validation_pipeline {
	File truth_vcf
	File query_vcf
  	File bedfile
	File reference_fasta
	File reference_fasta_index
  	String prefix

	call vcf_evaluation {
		input:
			truth_vcf = truth_vcf,
			query_vcf = query_vcf,
			bedfile = bedfile,
			prefix = prefix,
			reference_fasta_index = reference_fasta_index,
			reference_fasta = reference_fasta
	}
}

task vcf_evaluation {

	File truth_vcf
	File query_vcf
	File bedfile
	File reference_fasta
	File reference_fasta_index
	String prefix

	command {
		/opt/hap.py/bin/hap.py ${truth_vcf} ${query_vcf} -f ${bedfile} -o ${prefix} -r ${reference_fasta} --verbose --gender "none" -R ${bedfile}
	}

	runtime {
		docker: "pkrusche/hap.py"
  }

	output {
		File file1 = prefix + ".extended.csv"
		File file2 = prefix + ".metrics.json.gz"
		File file3 = prefix + ".roc.Locations.SNP.PASS.csv.gz"
		File file4 = prefix + ".roc.Locations.SNP.csv.gz"
		File file5 = prefix + ".roc.all.csv.gz"
		File file6 = prefix + ".roc.tsv"
		File file7 = prefix + ".runinfo.json"
		File file8 = prefix + ".summary.csv"
		File file9 = prefix + ".vcf.gz"
		File file10 = prefix + ".vcf.gz.tbi"
	}
}

